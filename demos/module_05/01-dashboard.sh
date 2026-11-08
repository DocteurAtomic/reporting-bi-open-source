#!/usr/bin/env bash
# Clip 5.1. The dashboard of the invoicing service, "Tableau de bord de la facturation"
# (01-dashboard.json): a text card that says where the numbers come from and what they leave
# out, the new question "Factures sans paiement par année" (01-unpaid-by-year.json, made or
# replaced), and four questions of modules 2 and 3, found by their names: "Chiffre d'affaires
# par stage", "Paiements par mode", "Encaissements par mois", "Encaissements par période".
# Everything goes in the collection "Facturation" (or the collection named in COLLECTION); a
# dashboard of the same name there is emptied and filled again. No filter yet: that is clip 5.2
# (02-filter.sh). Then runs each card through the dashboard and prints its first rows.
# Usage: ./demos/module_05/01-dashboard.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_05

coll=$(mb_collection "${COLLECTION:-Facturation}")
mb_save_card "$d/01-unpaid-by-year.json" "$coll" >/dev/null
dash=$(mb_save_dashboard "$d/01-dashboard.json" "$coll")
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null
echo "\"Tableau de bord de la facturation\" (id $dash, collection id $coll):"
json_sql "$mb_tmp/dash.json" "
    select concat_ws('|', dc->>'id', coalesce(dc->>'card_id', ''), coalesce(dc->'card'->>'name', '(text card)'))
      from j, jsonb_array_elements(doc->'dashcards') dc
     order by (dc->>'row')::int, (dc->>'col')::int" > "$mb_tmp/cards.txt"
echo '{"parameters":[]}' > "$mb_tmp/none.json"
while IFS='|' read -r dc cid card_name; do
    if [ -z "$cid" ]; then echo "-- dashcard $dc: $card_name"; continue; fi
    mb_call POST "/api/dashboard/$dash/dashcard/$dc/card/$cid/query" "$mb_tmp/answer.json" "$mb_tmp/none.json" >/dev/null
    json_sql "$mb_tmp/answer.json" "
        select format('-- dashcard %s: %s (question %s), %s rows', $dc, $(sql_text "$card_name"), $cid,
                      coalesce(jsonb_array_length(doc->'data'->'rows')::text, 'error ' || coalesce(doc->>'error', '')))
          from j"
    json_sql "$mb_tmp/answer.json" "
        select (select string_agg(coalesce(v, '(empty)'), ' | ' order by k) from jsonb_array_elements_text(r) with ordinality y(v, k))
          from j, jsonb_array_elements(doc->'data'->'rows') with ordinality z(r, n)
         where n <= 3 or n > jsonb_array_length(doc->'data'->'rows') - 1 order by n"
done < "$mb_tmp/cards.txt"
