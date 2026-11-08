#!/usr/bin/env bash
# Clip 6.3. What an AI client of Metabase can read of the definitions of the module: the
# glossary (GET /api/glossary), empty on a new lab, then filled with the two terms of
# 03-glossary.json (POST /api/glossary, or PUT /api/glossary/<id> when the term exists, so the
# script can run twice); the description of the model "Factures" and of its columns, and the
# description of the metric "Chiffre d'affaires HT" (GET /api/card/<id>).
# Needs the model and the metric of 01-model.sh and 02-metric.sh.
# Usage: ./demos/module_06/03-glossary.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_06

mb_call GET /api/glossary "$mb_tmp/glossary.json" >/dev/null
echo "-- The glossary before: $(json_sql "$mb_tmp/glossary.json" "select jsonb_array_length(doc->'data') from j") terms"

n=$(json_sql "$d/03-glossary.json" "select jsonb_array_length(doc) from j")
for i in $(seq 0 $((n - 1))); do
    json_sql "$d/03-glossary.json" "select doc->$i from j" > "$mb_tmp/term.json"
    term=$(json_sql "$mb_tmp/term.json" "select doc->>'term' from j")
    tid=$(json_sql "$mb_tmp/glossary.json" "
        select min((t->>'id')::int) from j, jsonb_array_elements(doc->'data') t
         where t->>'term' = $(sql_text "$term")")
    if [ -n "$tid" ]; then
        code=$(mb_call PUT "/api/glossary/$tid" "$mb_tmp/saved.json" "$mb_tmp/term.json")
    else
        code=$(mb_call POST /api/glossary "$mb_tmp/saved.json" "$mb_tmp/term.json")
    fi
    [ "$code" = 200 ] || { echo "Metabase did not save the term \"$term\" (HTTP $code)" >&2; exit 1; }
done

mb_call GET /api/glossary "$mb_tmp/glossary.json" >/dev/null
echo "-- The glossary after, GET /api/glossary:"
json_sql "$mb_tmp/glossary.json" "
    select (t->>'id') || ' | ' || (t->>'term') || ' | ' || (t->>'definition')
      from j, jsonb_array_elements(doc->'data') t order by (t->>'id')::int"

for name in "Factures" "Chiffre d'affaires HT"; do
    id=$(mb_card_id "$name")
    mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
    echo "-- \"$name\", GET /api/card/$id:"
    json_sql "$mb_tmp/card.json" "select (doc->>'type') || ' | ' || coalesce(doc->>'description', '(no description)') from j"
done
echo "-- The columns of the model, as described:"
mb_call GET "/api/card/$(mb_card_id Factures)" "$mb_tmp/card.json" >/dev/null
json_sql "$mb_tmp/card.json" "
    select (c->>'display_name') || ' | ' || coalesce(c->>'description', '(no description)')
      from j, jsonb_array_elements(doc->'result_metadata') c"
