#!/usr/bin/env bash
# Clip 2.3. The revenue by stage: from facture to the title of the stage through
# inscriptionfacture, inscription, session and stagelangue (left joins, the default of the
# query builder). First with one summary, which adds an invoice once per registration it
# covers; then with two summaries, which keep each invoice once per stage before adding them.
# The second is saved as "Chiffre d'affaires par stage" in the collection "Facturation".
# Usage: ./demos/module_02/03-revenue-by-stage.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_02

mb_run_template "$d/03-revenue-by-stage-one-step.json" "$mb_tmp/answer.json"
echo "-- One summary, sum of Montant HT by title (first rows):"
mb_rows "$mb_tmp/answer.json" | head -4

coll=$(mb_collection Facturation)
id=$(mb_save_card "$d/03-revenue-by-stage.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Chiffre d'affaires par stage\" (id $id), two summaries (first rows):"
mb_rows "$mb_tmp/answer.json" | head -4
json_sql "$mb_tmp/answer.json" "
    select count(*) || ' rows; with a title: ' || sum((r->>1)::numeric) filter (where r->>0 is not null)
           || '; without a title: ' || sum((r->>1)::numeric) filter (where r->>0 is null)
      from j, jsonb_array_elements(doc->'data'->'rows') r"
