#!/usr/bin/env bash
# Verifies a page of SQLPage, component by component, against reference queries run in psql.
# Usage: ./setup/verify-page.sh REFERENCES.sql [PAGE]
# - PAGE is the path of the page under site/, such as planning.sql; without it, the line
#   "-- check: page planning.sql" of REFERENCES.sql gives it.
# - The page is asked to SQLPage with the header Accept: application/json (SQLPage then sends
#   the same page as a JSON array: one object per component, then one object per row of that
#   component), so the check reads the numbers the page shows without reading its HTML.
#   SQLPage runs the page as lecture_bi, like the browser would.
# - A page whose query fails still answers 200: SQLPage puts an object with a key "error" in
#   the array, or a component "error" when the first query fails. The check stops on either.
# - REFERENCES.sql holds one query per expected component, each after a line
#   "-- component: LABEL". Each reference must give the same rows as one component of the
#   page, the order of the rows ignored (setup/compare-page.sql). A column of the reference
#   matches the key of the rows that holds its values, whatever the names: "value" in a
#   big_number, "x" and "y" in a chart, any alias in a table. The label only names the
#   reference in the messages; a component that matches no reference is reported, and does not
#   fail the check. Two references cannot match the same component.
# Exit codes, as check.sh: 0 every reference matches a component; 1 the lab or the arguments
# (SQLPage stopped, or not answering); 2 the page is missing (404) or one of its queries fails;
# 3 a reference matches no component; 4 a reference matches no component, and the closest one
# holds text where the reference holds numbers.
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

[ $# -ge 1 ] || verdict "FAIL lab: usage: $0 REFERENCES.sql [PAGE]"
ref=$1
[ -f "$ref" ] || verdict "FAIL lab: no file $ref"
page=${2:-$(sed -n 's/^-- check: page  *//p' "$ref" | tr -d '\r' | head -1)}
page=${page#/}
page=${page#site/}
[ -n "$page" ] || verdict "FAIL lab: no page given, and no line \"-- check: page NAME.sql\" in $ref"
sqlpage_url=http://127.0.0.1:${SQLPAGEPORT:-8080}

lab_running "$c" || verdict "FAIL lab: the container $c (PostgreSQL) is not running; start the lab with ./setup/install.sh"
lab_running "$c-sqlpage" \
    || verdict "FAIL lab: the container $c-sqlpage (SQLPage) is not running; start it with: docker compose --profile code up -d sqlpage"

code=$(curl -sS --max-time 60 -o "$tmp/page.json" -w '%{http_code}' -H 'Accept: application/json' \
    "$sqlpage_url/$page" 2>/dev/null || true)
[ "$code" = 000 ] && verdict "FAIL lab: SQLPage does not answer on $sqlpage_url"
[ "$code" = 404 ] && verdict "FAIL missing: SQLPage answers 404 for /$page: there is no file site/$page"
[ "$code" = 200 ] || verdict "FAIL error: SQLPage answers HTTP $code for /$page"
[ "$(json_sql "$tmp/page.json" "select jsonb_typeof(doc) from j" 2>/dev/null)" = array ] \
    || verdict "FAIL error: SQLPage did not send the page as JSON (is it a .sql file?)"

# A query of the page that fails: SQLPage writes the error of the database in the page, and
# stops there. It is a row {"error": ...} when a component was open, and a component
# {"component": "error", "description": ...} when none was (a failing first query).
error=$(json_sql "$tmp/page.json" "
    select concat_ws(' ', split_part(m, E'\n', 1), split_part(m, E'\n', 2))
      from j, jsonb_array_elements(doc) e,
           lateral (select coalesce(e->>'error', e->>'description') as m) x
     where e ? 'error' or e->>'component' = 'error' limit 1")
[ -z "$error" ] || verdict "FAIL error: a query of the page fails: $error"

echo "Page /$page: $(json_sql "$tmp/page.json" "
    select count(*) || ' components (' || coalesce(string_agg(e->>'component', ', ' order by n), '') || ')'
      from j, jsonb_array_elements(doc) with ordinality x(e, n)
     where e ? 'component'")"

# The reference queries, one file each.
awk -v dir="$tmp" '
    /^-- component: / { n++; label = substr($0, 15); sub(/\r$/, "", label); print label > (dir "/label-" n); next }
    n { print > (dir "/ref-" n ".sql") }' "$ref"
nref=$(ls "$tmp"/label-* 2>/dev/null | wc -l)
[ "$nref" -gt 0 ] || verdict "FAIL lab: no line \"-- component: LABEL\" in $ref"

# The names of the components, by number.
json_sql "$tmp/page.json" "
    select row_number() over (order by n) || '|' || (e->>'component')
      from j, jsonb_array_elements(doc) with ordinality x(e, n)
     where e ? 'component' order by n" > "$tmp/components.txt"
name_of() { sed -n "s/^$1|//p" "$tmp/components.txt"; }

# compare REFERENCE_NUMBER: one line per component with rows, "number|rank|verdict".
compare() {
    {
        echo '\set ON_ERROR_STOP on'
        echo 'create temp table j (doc jsonb);'
        echo 'copy j from stdin;'
        tr -d '\n\r\t' < "$tmp/page.json" | sed 's/\\/\\\\/g'
        printf '\n\\.\n'
        printf 'create temp view expected as\n%s\n;\n' "$(sed 's/;[[:space:]]*$//' "$tmp/ref-$1.sql" | tr -d '\r')"
        cat setup/compare-page.sql
    } | psql_lab -d pachadataformation -q -At 2>&1
}

matched=" "
fails=()
for n in $(seq 1 "$nref"); do
    label=$(cat "$tmp/label-$n")
    out=$(compare "$n")
    if ! printf '%s\n' "$out" | grep -qE '^[0-9]+\|[0-3]\|'; then
        if [ -z "$out" ]; then
            echo "FAIL reference \"$label\": the page has no component with rows"
            fails+=(rows)
            continue
        fi
        verdict "FAIL lab: the reference \"$label\" does not run in psql: $(printf '%s\n' "$out" | head -3 | tr '\n' ' ')"
    fi
    found=
    best=
    while IFS='|' read -r k rank detail; do
        case "$matched" in *" $k "*) continue ;; esac
        if [ "$rank" = 0 ]; then found="$k|$detail"; break; fi
        [ -z "$best" ] && best="$rank|$k|$detail"
    done < <(printf '%s\n' "$out" | grep -E '^[0-9]+\|[0-3]\|' | sort -t'|' -k2,2n -k1,1n)
    if [ -n "$found" ]; then
        k=${found%%|*}
        matched="$matched$k "
        echo "PASS reference \"$label\": component $k ($(name_of "$k")), ${found#*|PASS: }"
    else
        echo "FAIL reference \"$label\": no component of the page gives its rows"
        rank=${best%%|*}; rest=${best#*|}; k=${rest%%|*}; detail=${rest#*|}
        echo "  closest component $k ($(name_of "$k")): $detail"
        if [ "$rank" = 2 ]; then fails+=(columns); else fails+=(rows); fi
    fi
done

while IFS='|' read -r k name; do
    case "$name" in shell|shell-empty|title|text) continue ;; esac
    case "$matched" in *" $k "*) ;; *) echo "Note: the component $k ($name) matches no reference." ;; esac
done < "$tmp/components.txt"

case " ${fails[*]} " in
    *" rows "*)    verdict "FAIL rows: ${#fails[@]} reference(s) without a component, see above" ;;
    *" columns "*) verdict "FAIL columns: a reference matches no component, the closest one holds text where the reference holds numbers" ;;
esac
verdict "PASS: $nref components, the same as the references"
