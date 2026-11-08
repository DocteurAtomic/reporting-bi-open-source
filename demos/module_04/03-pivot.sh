#!/usr/bin/env bash
# Clip 4.3. The pivot table of the registrations not cancelled, by stage and by year of
# session, for the ten most followed stages (ties at the tenth place included).
# A pivot table needs a question of the query builder, and the query builder has no "ten
# first with ties", so the selection is written in SQL (03-top-stages-registrations.sql, one
# row per registration) and saved as "Inscriptions des stages les plus suivis"; the pivot
# table "Inscriptions par stage et par année" summarizes it in the query builder (clip 3.4),
# with a color range on the counts. Both are saved in the collection "Module 04".
# Prints the pivot rows as POST /api/card/<id>/query returns them: pivot-grouping 0 for a
# cell, 1 for the total of a year, 2 for the total of a stage, 3 for the grand total.
# Usage: ./demos/module_04/03-pivot.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_04
coll=$(mb_collection "Module 04")

json_sql "$d/03-top-stages-source.json" "
    select jsonb_set(doc, '{dataset_query,native,query}',
                     to_jsonb($(sql_text "$(cat "$d/03-top-stages-registrations.sql")")::text))
      from j" > "$mb_tmp/source.json"
src=$(mb_save_card "$mb_tmp/source.json" "$coll")
echo "-- \"Inscriptions des stages les plus suivis\" (id $src), in SQL"

json_sql "$d/03-top-stages-pivot.json" "
    select jsonb_set(doc, '{dataset_query,query,source-table}', to_jsonb('card__$src'::text)) from j" \
    > "$mb_tmp/pivot.json"
id=$(mb_save_card "$mb_tmp/pivot.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Inscriptions par stage et par année\" (id $id), a pivot table on question $src:"
mb_rows "$mb_tmp/answer.json"
