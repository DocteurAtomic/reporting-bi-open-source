#!/usr/bin/env bash
# Clip 8.1. The dashboard of the management, "Visites du catalogue" (01-dashboard.json), on the
# fact table entrepot.visite of ./setup/volume.sh: the questions "Visites et visiteurs par
# mois" (01-visits-by-month.json) and "Visites par année" (01-visits-by-year.json), made or
# replaced, in the collection "Module 08". Then runs each card through the dashboard, as the
# browser does when it opens it, and prints the running time Metabase reports (in ms), the
# number of rows and the visits added up; then the SQL that Metabase sends for the slow card,
# to run under EXPLAIN ANALYZE in psql (01-check.sql).
# Needs ./setup/volume.sh; the script asks Metabase to sync the schema entrepot and waits
# for the table (mb_sync of setup/mbql.sh).
# Usage: ./demos/module_08/01-dashboard.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_08

# Metabase sees a new schema after a sync: Admin > Databases > Sync database schema now.
mb_sync entrepot.visite

coll=$(mb_collection "Module 08")
mb_save_card "$d/01-visits-by-month.json" "$coll" >/dev/null
mb_save_card "$d/01-visits-by-year.json" "$coll" >/dev/null
dash=$(mb_save_dashboard "$d/01-dashboard.json" "$coll")
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null
echo "\"Visites du catalogue\" (id $dash, collection \"Module 08\", id $coll):"
json_sql "$mb_tmp/dash.json" "
    select concat_ws('|', dc->>'id', dc->>'card_id', dc->'card'->>'name')
      from j, jsonb_array_elements(doc->'dashcards') dc
     where dc->>'card_id' is not null
     order by (dc->>'row')::int, (dc->>'col')::int" > "$mb_tmp/cards.txt"
echo '{"parameters":[]}' > "$mb_tmp/none.json"
while IFS='|' read -r dc cid card_name; do
    mb_call POST "/api/dashboard/$dash/dashcard/$dc/card/$cid/query" "$mb_tmp/answer.json" "$mb_tmp/none.json" >/dev/null
    json_sql "$mb_tmp/answer.json" "
        select format('-- %s (question %s): %s ms, %s rows, %s visits, cached: %s', $(sql_text "$card_name"), $cid,
                      doc->>'running_time', jsonb_array_length(doc->'data'->'rows'),
                      (select sum((r->>1)::bigint) from jsonb_array_elements(doc->'data'->'rows') r),
                      coalesce(doc->>'cached', 'no'))
          from j"
    json_sql "$mb_tmp/answer.json" "
        select (select string_agg(coalesce(v, '(empty)'), ' | ' order by k) from jsonb_array_elements_text(r) with ordinality y(v, k))
          from j, jsonb_array_elements(doc->'data'->'rows') with ordinality z(r, n)
         where n <= 2 or n > jsonb_array_length(doc->'data'->'rows') - 2 order by n"
done < "$mb_tmp/cards.txt"

# The SQL of the slow card, compiled by Metabase without running it (POST /api/dataset/native).
id=$(mb_card_id "Visites et visiteurs par mois")
mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
json_sql "$mb_tmp/card.json" "select doc->'dataset_query' from j" > "$mb_tmp/query.json"
mb_call POST /api/dataset/native "$mb_tmp/compiled.json" "$mb_tmp/query.json" >/dev/null
echo "-- The SQL Metabase sends for \"Visites et visiteurs par mois\":"
json_sql "$mb_tmp/compiled.json" "select doc->>'query' from j"
