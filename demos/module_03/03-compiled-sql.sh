#!/usr/bin/env bash
# Clip 3.3: prints the SQL that Metabase sends to PostgreSQL for the saved question
# "Encaissements par période", with the value given to its field filter {{periode}}, or with
# no value at all. Through POST /api/dataset/native, which compiles a query without running it.
# Usage, from the root of the clone:
#   ./demos/module_03/03-compiled-sql.sh 2011-04                  April 2011
#   ./demos/module_03/03-compiled-sql.sh 2011-01-01~2011-03-31    a range of dates
#   ./demos/module_03/03-compiled-sql.sh                          no value
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
name="Encaissements par période"

mb_call GET /api/card "$tmp/cards.json" >/dev/null
id=$(json_sql "$tmp/cards.json" "
    select max((c->>'id')::int) from j, jsonb_array_elements(doc) c
     where c->>'name' = $(sql_text "$name") and not coalesce((c->>'archived')::boolean, false)")
[ -n "$id" ] || { echo "No question named \"$name\" in Metabase (clip 3.3)." >&2; exit 2; }
mb_call GET "/api/card/$id" "$tmp/card.json" >/dev/null

# The query of the question, plus the value of its parameter on {{periode}} when one is given.
json_sql "$tmp/card.json" "
    select doc->'dataset_query' || jsonb_build_object('parameters',
             case when $(sql_text "${1:-}") = '' then '[]'::jsonb
                  else (select jsonb_agg(jsonb_build_object('id', p->'id', 'type', p->'type',
                                                            'target', p->'target', 'value', $(sql_text "${1:-}")))
                          from jsonb_array_elements(doc->'parameters') p
                         where p->'target' = '[\"dimension\", [\"template-tag\", \"periode\"]]')
             end)
      from j" > "$tmp/native.json"
code=$(mb_call POST /api/dataset/native "$tmp/compiled.json" "$tmp/native.json")
[ "$code" = 200 ] || { echo "Metabase could not compile the query (HTTP $code): $(cat "$tmp/compiled.json")" >&2; exit 2; }
json_sql "$tmp/compiled.json" "select doc->>'query' from j"
