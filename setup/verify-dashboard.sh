#!/usr/bin/env bash
# Verifies a dashboard of Metabase, card by card, against reference queries run in psql.
# Usage: ./setup/verify-dashboard.sh "NAME OF THE DASHBOARD" REFERENCES.sql [VALUE]
# - The dashboard is found by its name with GET /api/search (retried for five seconds, like
#   check.sh), and confirmed by GET /api/dashboard/<id> (neither 404 nor archived). That answer
#   gives its cards, its filters, and the connections of each card (parameter_mappings).
# - Its date filter (the first filter of type date/..., in the order of the dashboard) receives
#   VALUE, a range of dates such as 2011-01-01~2011-12-31. Without VALUE, the line
#   "-- check: filter VALUE" of REFERENCES.sql gives it. A year alone ("2011") is not a range:
#   Metabase reads it as something else and the cards come back empty.
# - Each card that runs a question must be connected to that filter. It is run as the browser
#   runs it, by POST /api/dashboard/<id>/dashcard/<dcid>/card/<cid>/query with the value of the
#   filter: the only route that applies the filter of the dashboard (POST /api/card/<id>/query
#   runs the question alone and ignores it).
# - REFERENCES.sql holds one query per expected card, each after a line "-- card: LABEL". A
#   query may use :'debut' and :'fin', the two ends of VALUE. Each reference must give the same
#   rows as one card of the dashboard, the order of the rows ignored (setup/compare-card.sql).
#   The label only names the reference in the messages; a card that matches no reference is
#   reported, and does not fail the check. Text cards are left out.
# Exit codes, as check.sh: 0 every reference matches a card and every card is connected;
# 1 the lab, the API key or the arguments; 2 the dashboard is missing or archived, it has no date
# filter that takes a range, or a card fails when it runs; 3 a card is not connected to the
# filter, or a reference matches no card; 4 a reference matches no card, and the cards left
# differ from it by their columns.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

verdict() {
    printf '%s\n' "$1"
    case "$1" in
        PASS*) exit 0 ;;
        'FAIL missing'*|'FAIL error'*) exit 2 ;;
        'FAIL rows'*) exit 3 ;;
        'FAIL columns'*) exit 4 ;;
        *) exit 1 ;;
    esac
}

[ $# -ge 2 ] || verdict "FAIL lab: usage: $0 \"NAME OF THE DASHBOARD\" REFERENCES.sql [2011-01-01~2011-12-31]"
name=$1
ref=$2
[ -f "$ref" ] || verdict "FAIL lab: no file $ref"
value=${3:-$(sed -n 's/^-- check: filter  *//p' "$ref" | tr -d '\r' | head -1)}
[[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}~[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
    || verdict "FAIL lab: the value of the filter must be a range of dates, such as 2011-01-01~2011-12-31 (got \"$value\")"
debut=${value%~*}
fin=${value#*~}

lab_running "$c" || verdict "FAIL lab: the container $c (PostgreSQL) is not running; start the lab with ./setup/install.sh"
lab_running "$mbc" || verdict "FAIL lab: the container $mbc (Metabase) is not running; start the lab with ./setup/install.sh"
mb_healthy || verdict "FAIL lab: Metabase does not answer on $mb_url/api/health"
[ -n "${MB_API_KEY:-}" ] || verdict "FAIL lab: no API key in .env (MB_API_KEY); make one with ./setup/api-key.sh"

# urlencode TEXT: TEXT for a query string, byte by byte.
urlencode() {
    local LC_ALL=C s=$1 out= i ch
    for ((i = 0; i < ${#s}; i++)); do
        ch=${s:i:1}
        case "$ch" in
            [a-zA-Z0-9.~_-]) out+=$ch ;;
            *) printf -v ch '%%%02X' "'$ch"; out+=$ch ;;
        esac
    done
    printf '%s' "$out"
}

# The dashboard, by its name: the search is retried for five seconds, each answer confirmed.
id=
deadline=$((SECONDS + 5))
while :; do
    code=$(mb_call GET "/api/search?q=$(urlencode "$name")&models=dashboard" "$tmp/search.json")
    { [ "$code" = 401 ] || [ "$code" = 403 ]; } && verdict "FAIL lab: Metabase refuses the API key of .env (HTTP $code)"
    if [ "$code" = 200 ]; then
        for candidate in $(json_sql "$tmp/search.json" "
                select r->>'id'
                  from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) r
                 where r->>'model' = 'dashboard' and r->>'name' = $(sql_text "$name")
                 order by r->>'updated_at' desc"); do
            code=$(mb_call GET "/api/dashboard/$candidate" "$tmp/dashboard.json")
            if [ "$code" = 200 ] && [ "$(json_sql "$tmp/dashboard.json" "select coalesce((doc->>'archived')::boolean, false) from j")" = f ]; then
                id=$candidate
                break
            fi
        done
        [ -n "$id" ] && break
    fi
    [ "$SECONDS" -ge "$deadline" ] && break
    sleep 1
done
[ -n "$id" ] || verdict "FAIL missing: no dashboard named \"$name\" in Metabase (saved, not in the trash)"
echo "Dashboard \"$name\" (id $id):"

# Its date filter: the first filter whose type starts with date/.
IFS='|' read -r fid ftype fname ndate < <(json_sql "$tmp/dashboard.json" "
    select p->>'id', p->>'type', p->>'name', count(*) over ()
      from j, jsonb_array_elements(coalesce(doc->'parameters', '[]')) with ordinality x(p, n)
     where p->>'type' like 'date/%'
     order by n limit 1")
[ -n "${fid:-}" ] || verdict "FAIL error: the dashboard has no date filter (Filter > Date picker)"
[ "$ftype" = date/single ] \
    && verdict "FAIL error: the filter \"$fname\" takes a single date ($ftype), not a year; choose the type All options"
[ "${ndate:-1}" -gt 1 ] && echo "Note: the dashboard has $ndate date filters; the first one, \"$fname\", is checked."
echo "Filter \"$fname\" ($ftype): $value"
printf '{"parameters":[{"id":%s,"type":%s,"value":%s}]}\n' \
    "$(json_text "$fid")" "$(json_text "$ftype")" "$(json_text "$value")" > "$tmp/value.json"

# Its cards that run a question: dashcard id, card id, connected to the filter or not, name.
json_sql "$tmp/dashboard.json" "
    select concat_ws('|', dc->>'id', dc->>'card_id',
                     exists (select from jsonb_array_elements(coalesce(dc->'parameter_mappings', '[]')) m
                              where m->>'parameter_id' = $(sql_text "$fid")),
                     dc->'card'->>'name')
      from j, jsonb_array_elements(doc->'dashcards') dc
     where dc->>'card_id' is not null
     order by (dc->>'row')::int, (dc->>'col')::int" > "$tmp/cards.txt"
[ -s "$tmp/cards.txt" ] || verdict "FAIL missing: the dashboard has no card that runs a question"

fails=()
ran=()
while IFS='|' read -r dc cid connected card; do
    if [ "$connected" != t ]; then
        echo "FAIL card \"$card\": not connected to the filter \"$fname\", it shows the same rows whatever the value"
        fails+=(rows)
        continue
    fi
    code=$(mb_call POST "/api/dashboard/$id/dashcard/$dc/card/$cid/query" "$tmp/answer-$dc.json" "$tmp/value.json")
    status=$(json_sql "$tmp/answer-$dc.json" "
        select coalesce(doc->>'status', '') || '|'
               || split_part(coalesce(doc->>'error', doc->'via'->0->>'error', ''), E'\n', 1)
          from j" 2>/dev/null) || status='|'
    if [ "${status%%|*}" != completed ]; then
        echo "FAIL card \"$card\": does not run (HTTP $code): ${status#*|}"
        fails+=(error)
        continue
    fi
    ran+=("$dc|$card")
done < "$tmp/cards.txt"

# The reference queries, one file each.
awk -v dir="$tmp" '
    /^-- card: / { n++; label = substr($0, 10); sub(/\r$/, "", label); print label > (dir "/label-" n); next }
    n { print > (dir "/ref-" n ".sql") }' "$ref"
nref=$(ls "$tmp"/label-* 2>/dev/null | wc -l)
[ "$nref" -gt 0 ] || verdict "FAIL lab: no line \"-- card: LABEL\" in $ref"

# compare DASHCARD REFERENCE_NUMBER: the verdict of setup/compare-card.sql, then its details.
compare() {
    {
        echo '\set ON_ERROR_STOP on'
        echo '\set ordered false'
        printf '\\set debut %s\n\\set fin %s\n' "$debut" "$fin"
        echo 'create temp table j (doc jsonb);'
        echo 'copy j from stdin;'
        tr -d '\n\r\t' < "$tmp/answer-$1.json" | sed 's/\\/\\\\/g'
        printf '\n\\.\n'
        printf 'create temp view expected as\n%s\n;\n' "$(sed 's/;[[:space:]]*$//' "$tmp/ref-$2.sql" | tr -d '\r')"
        cat setup/compare-card.sql
    } | psql_lab -d pachadataformation -q -At 2>&1
}

matched=" "
for n in $(seq 1 "$nref"); do
    label=$(cat "$tmp/label-$n")
    found=
    best=
    named=
    # The card named like the reference is tried first: an empty answer matches any
    # reference with the same kinds of columns.
    candidates=()
    for entry in "${ran[@]}"; do [ "${entry#*|}" = "$label" ] && candidates+=("$entry"); done
    for entry in "${ran[@]}"; do [ "${entry#*|}" != "$label" ] && candidates+=("$entry"); done
    for entry in "${candidates[@]}"; do
        dc=${entry%%|*}; card=${entry#*|}
        case "$matched" in *" $dc "*) continue ;; esac
        out=$(compare "$dc" "$n")
        last=$(printf '%s\n' "$out" | tail -1)
        case "$last" in
            PASS*) found="$dc|$card|${last#PASS: }"; break ;;
            'FAIL rows'*|'FAIL columns'*)
                # The details shown are those of the card named like the reference, or else
                # of the first card with the same columns, or else of the first card.
                kind=rows; case "$last" in 'FAIL columns'*) kind=columns ;; esac
                if [ "$card" = "$label" ]; then
                    best="$kind|$card|$out"; named=1
                elif [ -z "$named" ] && { [ -z "$best" ] || { [ "${best%%|*}" = columns ] && [ "$kind" = rows ]; }; }; then
                    best="$kind|$card|$out"
                fi ;;
            *) verdict "FAIL lab: the reference \"$label\" does not run in psql: $last" ;;
        esac
    done
    if [ -n "$found" ]; then
        IFS='|' read -r dc card detail <<< "$found"
        matched="$matched$dc "
        echo "PASS reference \"$label\": card \"$card\", $detail"
    else
        echo "FAIL reference \"$label\": no card of the dashboard gives its rows"
        if [ -n "$best" ]; then
            kind=${best%%|*}; rest=${best#*|}; card=${rest%%|*}; out=${rest#*|}
            echo "  closest card \"$card\":"
            printf '%s\n' "$out" | sed 's/^/    /'
            fails+=("$kind")
        else
            fails+=(rows)
        fi
    fi
done

for entry in "${ran[@]}"; do
    dc=${entry%%|*}
    case "$matched" in *" $dc "*) ;; *) echo "Note: the card \"${entry#*|}\" matches no reference." ;; esac
done

case " ${fails[*]} " in
    *" error "*)   verdict "FAIL error: a card of the dashboard does not run" ;;
    *" rows "*)    verdict "FAIL rows: ${#fails[@]} problem(s) on the dashboard, see above" ;;
    *" columns "*) verdict "FAIL columns: a reference matches no card, the cards left have other columns" ;;
esac
verdict "PASS: $nref cards, the same as the references, all connected to the filter"
