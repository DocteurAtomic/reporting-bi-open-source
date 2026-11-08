#!/usr/bin/env bash
# Checks the lab, or the exercise of a module.
# Usage: ./setup/check.sh NN
#   00 checks the lab: Metabase answers, the API key MB_API_KEY of .env is accepted, exactly one
#   database is connected besides the sample database (pachadataformation, read as
#   lecture_bi), and the role lecture_bi can only connect, use the schemas and read.
#   01, 02... check the exercise of the module, whose kind is given by the first lines of
#   exercises/module_NN/reference.sql:
#   - "-- check: card" (the default): the question saved as "Exercice NN" is found by
#     GET /api/search (retried for five seconds: the search index sees a new question about a
#     second after it is saved, and keeps a deleted one for a while), confirmed by
#     GET /api/card/<id> (neither 404 nor archived), run by POST /api/card/<id>/query, and its
#     rows are compared with the rows of reference.sql run in psql (setup/compare-card.sql).
#     The order of the rows is ignored, unless the line is "-- check: card ordered".
#     A native question with variables is run with the values given by lines such as
#     "-- check: parameter dimension periode date/all-options 2007-01-01~2007-12-31"
#     (kind of target, dimension for a field filter or variable for a basic variable, name of
#     the variable, type of the parameter, value), one line per variable, in the first ten
#     lines: POST /api/card/<id>/query without parameters applies the default value of each
#     variable and drops a field filter that has none, so the check passes the value itself.
#     When the exercise asks for a way of drawing the answer, which the rows do not show, lines
#     such as "-- check: display line" (the kind of chart of the card) and
#     "-- check: setting line.missing zero interpolate" (a key of visualization_settings, the
#     value wanted, and the value Metabase uses when the key is not set) in the first ten lines
#     are checked once the rows are right. A setting is read for each metric of the answer in
#     series_settings first, where the chart editor writes the options of a series, then at the
#     top of visualization_settings, then the default of the line.
#   - "-- check: dashboard" (module 5) and "-- check: permissions" (module 7): not written yet
#     in this state of the repository.
# The JSON answers of Metabase are read by PostgreSQL (jsonb), in the container: the script
# needs bash and curl, nothing else.
# Exit codes: 0 pass; 1 the lab or the check itself has a problem (a container stopped,
# Metabase not answering, no API key or a refused one); 2 the question is missing, archived or
# fails when it runs; 3 the rows differ, or the chart or one of its settings is not the one
# asked for; 4 the columns differ (count, or numbers against text).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
case "${1:-}" in [0-9][0-9]) nn=$1 ;; *) echo "usage: $0 NN" >&2; exit 1;; esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

verdict() {
    [ -n "$1" ] && printf '%s\n' "$1"
    case "$(printf '%s\n' "$1" | tail -1)" in
        PASS*)            if [ "$nn" = 00 ]; then echo "Lab: ready."; else echo "Exercise $nn: passed."; fi; exit 0 ;;
        'FAIL missing'*|'FAIL error'*) exit 2 ;;
        'FAIL rows'*|'FAIL display'*) exit 3 ;;
        'FAIL columns'*)  exit 4 ;;
        'FAIL lab'*)      exit 1 ;;
        *) echo "Check $nn: the check could not run to the end (see the message above)." >&2; exit 1 ;;
    esac
}

# The checks every exercise needs: both containers, Metabase, the API key.
lab_running "$c" || verdict "FAIL lab: the container $c (PostgreSQL) is not running; start the lab with ./setup/install.sh"
lab_running "$mbc" || verdict "FAIL lab: the container $mbc (Metabase) is not running; start the lab with ./setup/install.sh"
mb_healthy || verdict "FAIL lab: Metabase does not answer on $mb_url/api/health (it takes about half a minute to start)"
[ -n "${MB_API_KEY:-}" ] || verdict "FAIL lab: no API key in .env (MB_API_KEY); make one with ./setup/api-key.sh"
code=$(mb_call GET /api/database "$tmp/databases.json")
[ "$code" = 200 ] || verdict "FAIL lab: Metabase refuses the API key of .env (HTTP $code); make a new one with ./setup/api-key.sh --force"

if [ "$nn" = 00 ]; then
    # The databases connected in Metabase, the sample database (is_sample) apart.
    IFS='|' read -r n samples db_engine dbname user < <(json_sql "$tmp/databases.json" "
        select count(*) filter (where not s), count(*) filter (where s),
               max(d->>'engine') filter (where not s), max(d->'details'->>'dbname') filter (where not s),
               max(d->'details'->>'user') filter (where not s)
          from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d,
               lateral (select coalesce((d->>'is_sample')::boolean, false) as s) x")
    [ "${n:-0}" = 1 ] || verdict "FAIL lab: ${n:-0} databases connected in Metabase besides the sample database, 1 expected (pachadataformation)"
    [ "$db_engine" = postgres ] && [ "$dbname" = pachadataformation ] \
        || verdict "FAIL lab: the database connected in Metabase is $dbname ($db_engine), not pachadataformation (postgres)"
    [ "$user" = lecture_bi ] || verdict "FAIL lab: Metabase connects to pachadataformation as $user, not as lecture_bi"
    if [ "${samples:-0}" != 0 ]; then
        echo "Note: the sample database is still in Metabase (module 1 removes it, module 9 brings it back)."
    fi
    verdict "$(psql_lab -d pachadataformation -At <<'SQL'
select case
    when r.rolname is null then 'FAIL lab: the role lecture_bi does not exist; run ./setup/install.sh'
    when r.rolsuper or r.rolcreatedb or r.rolcreaterole or r.rolbypassrls
        then 'FAIL lab: lecture_bi has more than connect, usage and select (superuser, createdb, createrole or bypassrls)'
    when not r.rolcanlogin then 'FAIL lab: lecture_bi cannot log in'
    when not has_database_privilege('lecture_bi', 'pachadataformation', 'CONNECT')
        then 'FAIL lab: lecture_bi cannot connect to pachadataformation'
    when has_database_privilege('lecture_bi', 'pachadataformation', 'CREATE')
      or has_schema_privilege('lecture_bi', 'public', 'CREATE')
        then 'FAIL lab: lecture_bi can create objects in pachadataformation'
    when not has_table_privilege('lecture_bi', 'contact.societe', 'SELECT')
        then 'FAIL lab: lecture_bi cannot read contact.societe'
    when exists (select from information_schema.role_table_grants
                  where grantee = 'lecture_bi' and privilege_type not in ('SELECT', 'REFERENCES'))
        then 'FAIL lab: lecture_bi can write in a table'
    else 'PASS: Metabase answers, the API key is accepted, one database (pachadataformation as lecture_bi), lecture_bi only reads'
    end
  from (select 1) one left join pg_roles r on r.rolname = 'lecture_bi';
SQL
)"
fi

dir=exercises/module_$nn
ref=$dir/reference.sql
if [ ! -f "$ref" ]; then
    echo "No $ref in this state of the repository." >&2
    exit 1
fi
kind=$(head -5 "$ref" | sed -n -e '/^-- check: parameter /d' -e '/^-- check: display /d' \
    -e '/^-- check: setting /d' -e 's/^-- check: *//p' | head -1)
case "${kind:-card}" in
    card)         ordered=false ;;
    'card ordered') ordered=true ;;
    dashboard)
        # Module 5: find the dashboard "Exercice NN", read its dashcards and their
        # parameter_mappings, and run each card through
        # POST /api/dashboard/<id>/dashcard/<dcid>/card/<cid>/query with the filter value.
        echo "The check of a dashboard is not written yet in this state of the repository." >&2
        exit 1 ;;
    permissions)
        # Module 7: read the permission graph and the collection graph, and run a query that
        # must be refused under the restricted account.
        echo "The check of permissions is not written yet in this state of the repository." >&2
        exit 1 ;;
    *) echo "Unknown kind of check in $ref: $kind" >&2; exit 1 ;;
esac

# The question, by its name. The search is retried for five seconds; each card it returns is
# confirmed by GET /api/card/<id>, the most recently changed first.
name="Exercice $nn"
id=
deadline=$((SECONDS + 5))
while :; do
    code=$(mb_call GET "/api/search?q=Exercice%20$nn&models=card" "$tmp/search.json")
    if [ "$code" = 200 ]; then
        ids=$(json_sql "$tmp/search.json" "
            select r->>'id'
              from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) r
             where r->>'model' = 'card' and r->>'name' = $(sql_text "$name")
               and not coalesce((r->>'archived')::boolean, false)
             order by r->>'updated_at' desc")
        found=0
        for candidate in $ids; do
            code=$(mb_call GET "/api/card/$candidate" "$tmp/card.json")
            if [ "$code" = 200 ] && [ "$(json_sql "$tmp/card.json" "select coalesce((doc->>'archived')::boolean, false) from j")" = f ]; then
                found=$((found + 1))
                [ -z "$id" ] && id=$candidate
            fi
        done
        [ -n "$id" ] && break
    fi
    [ "$SECONDS" -ge "$deadline" ] && break
    sleep 1
done
[ -n "$id" ] || verdict "FAIL missing: no question named \"$name\" in Metabase (saved, not in the trash)"
if [ "$found" -gt 1 ]; then
    echo "Note: $found questions are named \"$name\"; the most recently changed one is checked (id $id)."
fi

echo "Question \"$name\" (id $id):"

# The values of the variables, from the "-- check: parameter" lines of reference.sql. Each one
# is sent with the id that the question gives to its variable; a variable missing from the
# question is reported, and the rows then tell whether the answer holds; a basic variable where
# the line asks for a field filter fails at once (code 2), as Metabase would refuse the value.
params=
while read -r target tag ptype pvalue; do
    [ -n "$pvalue" ] || continue
    code=$(mb_call GET "/api/card/$id" "$tmp/card.json")
    IFS='|' read -r tag_id tag_type < <(json_sql "$tmp/card.json" "
        select coalesce(t->>'id', ''), coalesce(t->>'type', '')
          from j, lateral (select coalesce(doc->'dataset_query'->'stages'->0->'template-tags',
                                           doc->'dataset_query'->'native'->'template-tags') as tags) q,
               lateral (select e from jsonb_array_elements(case jsonb_typeof(q.tags) when 'array' then q.tags else '[]' end) e
                        union all
                        select v from jsonb_each(case jsonb_typeof(q.tags) when 'object' then q.tags else '{}' end) x(k, v)) w(t)
         where t->>'name' = $(sql_text "$tag")")
    if [ -z "$tag_id" ]; then
        echo "Note: the question has no variable {{$tag}}; it runs without the value $pvalue."
        continue
    fi
    if [ "$target" = dimension ] && [ "$tag_type" != dimension ]; then
        verdict "FAIL error: {{$tag}} is a $tag_type variable, and the exercise asks for a field filter (variable type: field filter)"
    fi
    echo "Variable {{$tag}}: $pvalue"
    params="$params${params:+,}{\"id\":$(json_text "$tag_id"),\"type\":$(json_text "$ptype"),\"target\":[\"$target\",[\"template-tag\",$(json_text "$tag")]],\"value\":$(json_text "$pvalue")}"
done < <(head -10 "$ref" | sed -n 's/^-- check: parameter  *//p' | tr -d '\r')
if [ -n "$params" ]; then
    printf '{"parameters":[%s]}\n' "$params" > "$tmp/parameters.json"
    code=$(mb_call POST "/api/card/$id/query" "$tmp/result.json" "$tmp/parameters.json")
else
    code=$(mb_call POST "/api/card/$id/query" "$tmp/result.json")
fi
status='|'
if [ -s "$tmp/result.json" ]; then
    status=$(json_sql "$tmp/result.json" "
        select coalesce(doc->>'status', '') || '|'
               || split_part(coalesce(doc->>'error', doc->'via'->0->>'error', ''), E'\n', 1)
          from j" 2>/dev/null) || status='|'
fi
[ "${status%%|*}" = completed ] || verdict "FAIL error: the question does not run (HTTP $code): ${status#*|}"

script() {
    echo '\set ON_ERROR_STOP on'
    echo "\\set ordered $ordered"
    echo 'create temp table j (doc jsonb);'
    echo 'copy j from stdin;'
    tr -d '\n\r\t' < "$tmp/result.json" | sed 's/\\/\\\\/g'
    printf '\n\\.\n'
    printf 'create temp view expected as\n%s\n;\n' "$(sed 's/;[[:space:]]*$//' "$ref" | tr -d '\r')"
    cat setup/compare-card.sql
}
rows=$(script | psql_lab -d pachadataformation -q -At)

# The kind of chart and its settings, once the rows are right: "-- check: display" and
# "-- check: setting" lines of reference.sql. The metrics of the answer (the summaries of the
# query builder; every column but the first for a native question) name its series.
want_display=$(head -10 "$ref" | sed -n 's/^-- check: display  *//p' | tr -d '\r' | head -1)
settings=$(head -10 "$ref" | sed -n 's/^-- check: setting  *//p' | tr -d '\r')
case "$(printf '%s\n' "$rows" | tail -1)" in PASS*) ;; *) verdict "$rows" ;; esac
[ -n "$want_display$settings" ] || verdict "$rows"
printf '%s\n' "$rows"
code=$(mb_call GET "/api/card/$id" "$tmp/card.json")
[ "$code" = 200 ] || verdict "FAIL error: the question cannot be read (HTTP $code)"
if [ -n "$want_display" ]; then
    display=$(json_sql "$tmp/card.json" "select doc->>'display' from j")
    [ "$display" = "$want_display" ] \
        || verdict "FAIL display: the question is drawn as $display, and the exercise asks for $want_display"
    echo "PASS: drawn as $display"
fi
metrics=$(json_sql "$tmp/result.json" "
    select coalesce(string_agg(c->>'name', ',' order by i) filter (where c->>'source' = 'aggregation'),
                    string_agg(c->>'name', ',' order by i) filter (where i > 1), '')
      from j, jsonb_array_elements(doc->'data'->'cols') with ordinality x(c, i)")
while read -r key want default; do
    [ -n "$want" ] || continue
    got=$(json_sql "$tmp/card.json" "
        select string_agg(distinct coalesce(vs->'series_settings'->m->>$(sql_text "$key"),
                                            vs->>$(sql_text "$key"), $(sql_text "${default:-(not set)}")), ', ')
          from j, lateral (select coalesce(doc->'visualization_settings', '{}') as vs) v,
               unnest(string_to_array($(sql_text "$metrics"), ',') || '{}'::text[]) m
         where m is not null")
    [ -z "$got" ] && got=$(json_sql "$tmp/card.json" "
        select coalesce(doc->'visualization_settings'->>$(sql_text "$key"), $(sql_text "${default:-(not set)}")) from j")
    [ "$got" = "$want" ] || verdict "FAIL display: the setting $key is $got, and the exercise asks for $want"
    echo "PASS: $key is $want"
done < <(printf '%s\n' "$settings")
verdict "PASS: the rows, the chart and its settings are the ones asked for"
