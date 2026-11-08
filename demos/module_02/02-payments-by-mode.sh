#!/usr/bin/env bash
# Clip 2.2. The payments received, by payment mode: table suivifacture, count and sum of
# montant by typepaiement, first on the whole table, then filtered on 2011, then joined to
# reference.modepaiement to read the name of the mode. The last state is saved as
# "Paiements par mode" in the collection "Facturation", made if missing.
# Usage: ./demos/module_02/02-payments-by-mode.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_02

# The same question without the filter of 2011 and without the join.
json_sql "$d/02-payments-by-mode.json" "
    select jsonb_set(doc #- '{dataset_query,query,filter}' #- '{dataset_query,query,joins}'
                         #- '{dataset_query,query,breakout,1}', '{name}', '\"whole table\"')
      from j" > "$mb_tmp/whole.json"
mb_run_template "$mb_tmp/whole.json" "$mb_tmp/answer.json"
echo "-- Whole table, no filter:"
mb_rows "$mb_tmp/answer.json"

coll=$(mb_collection Facturation)
id=$(mb_save_card "$d/02-payments-by-mode.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Paiements par mode\" (id $id, collection Facturation id $coll), filtered on 2011, joined to the modes:"
mb_rows "$mb_tmp/answer.json"
echo "-- The SQL that Metabase sends to PostgreSQL:"
json_sql "$mb_tmp/answer.json" "select doc->'data'->'native_form'->>'query' from j"
