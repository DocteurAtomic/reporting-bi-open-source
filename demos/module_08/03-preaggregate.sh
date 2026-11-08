#!/usr/bin/env bash
# Clip 8.3. The dashboard "Visites du catalogue" moved onto the materialized view
# entrepot.visites_par_mois of 03-matview.sql: the questions "Visites et visiteurs par mois (vue
# matérialisée)" and "Visites par année (vue matérialisée)", made or replaced in the collection
# "Module 08", take the place of the cards of 01-dashboard.sh on the dashboard. Then runs each
# card twice through the dashboard and prints its running time, the visits added up, and
# whether the answer came from the cache: a query faster than the minimum duration of the
# adaptive policy (one second) is never cached.
# Needs 03-matview.sql run in psql; the script asks Metabase to sync the schema and waits for
# the view.
# Usage: ./demos/module_08/03-preaggregate.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_08

mb_sync entrepot.visites_par_mois
coll=$(mb_collection "Module 08")
mb_save_card "$d/03-visits-by-month-view.json" "$coll" >/dev/null
mb_save_card "$d/03-visits-by-year-view.json" "$coll" >/dev/null
dash=$(mb_save_dashboard "$d/03-dashboard.json" "$coll")
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null
echo "\"Visites du catalogue\" (id $dash), on the materialized view:"
json_sql "$mb_tmp/dash.json" "
    select concat_ws('|', dc->>'id', dc->>'card_id', dc->'card'->>'name')
      from j, jsonb_array_elements(doc->'dashcards') dc
     where dc->>'card_id' is not null
     order by (dc->>'row')::int, (dc->>'col')::int" > "$mb_tmp/cards.txt"
echo '{"parameters":[]}' > "$mb_tmp/none.json"
for run in 1 2; do
    while IFS='|' read -r dc cid card_name; do
        mb_call POST "/api/dashboard/$dash/dashcard/$dc/card/$cid/query" "$mb_tmp/answer.json" "$mb_tmp/none.json" >/dev/null
        json_sql "$mb_tmp/answer.json" "
            select format('-- run %s, %s (question %s): %s ms, %s rows, %s visits, cached: %s', $run,
                          $(sql_text "$card_name"), $cid, doc->>'running_time', jsonb_array_length(doc->'data'->'rows'),
                          (select sum((r->>1)::numeric)::bigint from jsonb_array_elements(doc->'data'->'rows') r),
                          coalesce(doc->>'cached', 'no'))
              from j"
    done < "$mb_tmp/cards.txt"
done
