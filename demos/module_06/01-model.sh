#!/usr/bin/env bash
# Clip 6.1. Two totals for 2011 first: the column of the card "Chiffre d'affaires par stage"
# of the dashboard of module 5, added up under the filter 2011 (what the management reads),
# against the invoices of 2011 (what the billing department reads, 02-check.sql of the clip).
# Then the model "Factures": one row per invoice, with the company of the registration joined
# once (facture, inscriptionfacture, inscription, contact, societe, then one summary by
# invoice, date, amount and company), saved in the collection "Module 06", its columns named
# and described as in the metadata editor of the model; the count of its rows; and a question
# that starts from the model, the invoices of 2011 by company.
# Usage: ./demos/module_06/01-model.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_06

# The card of the dashboard of module 5, run through the dashboard with 2011.
coll5=$(mb_collection "Module 05")
mb_call GET "/api/collection/$coll5/items?models=dashboard" "$mb_tmp/items.json" >/dev/null
dash=$(json_sql "$mb_tmp/items.json" "
    select min((i->>'id')::int) from j, jsonb_array_elements(doc->'data') i
     where i->>'name' = 'Tableau de bord de la facturation'")
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null
IFS='|' read -r dcid cid pid < <(json_sql "$mb_tmp/dash.json" "
    select dc->>'id', dc->>'card_id', doc->'parameters'->0->>'id'
      from j, jsonb_array_elements(doc->'dashcards') dc
     where dc->'card'->>'name' = 'Chiffre d''affaires par stage'")
printf '{"parameters":[{"id":"%s","type":"date/all-options","value":"2011-01-01~2011-12-31"}]}' "$pid" \
    > "$mb_tmp/filter.json"
mb_call POST "/api/dashboard/$dash/dashcard/$dcid/card/$cid/query" "$mb_tmp/by-stage.json" "$mb_tmp/filter.json" >/dev/null
echo "-- \"Chiffre d'affaires par stage\" on the dashboard (id $dash), filter 2011:"
json_sql "$mb_tmp/by-stage.json" "
    select count(*) || ' stages; the column added up: ' || sum((r->>1)::numeric)
      from j, jsonb_array_elements(doc->'data'->'rows') r"

# The model, its columns, its rows.
coll=$(mb_collection "Module 06")
model=$(mb_save_card "$d/01-model-factures.json" "$coll")
mb_describe_model "$model" "$d/01-model-columns.json"
echo "-- Model \"Factures\" (id $model), its columns:"
json_sql "$mb_tmp/model.json" "
    select (c->>'name') || ' | ' || (c->>'display_name') || ' | ' || coalesce(c->>'description', '')
      from j, jsonb_array_elements(doc->'result_metadata') c"
mb_run_template "$d/01-model-count.json" "$mb_tmp/count.json"
echo "-- The rows of the model:"
mb_rows "$mb_tmp/count.json"

id=$(mb_save_card "$d/01-invoices-by-company.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Factures de 2011 par société\" (id $id), first rows:"
mb_rows "$mb_tmp/answer.json" | head -4
json_sql "$mb_tmp/answer.json" "
    select count(*) || ' companies; ' || sum((r->>1)::int) || ' invoices'
      from j, jsonb_array_elements(doc->'data'->'rows') r"
