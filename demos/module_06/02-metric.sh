#!/usr/bin/env bash
# Clip 6.2. The metric "Chiffre d'affaires HT": the sum of Montant HT on the model "Factures",
# defined once with its description, saved in the collection "Module 06". Run alone, it adds up
# every invoice, the 105 without a date included. Then two questions that pick the metric in
# Summarize instead of writing the sum again: the revenue of 2011, and the revenue of 2011 by
# company, whose rows add up to the same total since an invoice has one company at most.
# Needs the model of 01-model.sh.
# Usage: ./demos/module_06/02-metric.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_06
coll=$(mb_collection "Module 06")

metric=$(mb_save_card "$d/02-metric-revenue.json" "$coll")
mb_run_card "$metric" "$mb_tmp/answer.json"
echo "-- Metric \"Chiffre d'affaires HT\" (id $metric), alone:"
mb_rows "$mb_tmp/answer.json"

id=$(mb_save_card "$d/02-revenue-2011.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Chiffre d'affaires HT de 2011\" (id $id):"
mb_rows "$mb_tmp/answer.json"

id=$(mb_save_card "$d/02-revenue-2011-by-company.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Chiffre d'affaires HT de 2011 par société\" (id $id), first rows:"
mb_rows "$mb_tmp/answer.json" | head -4
json_sql "$mb_tmp/answer.json" "
    select count(*) || ' companies; the column added up: ' || sum((r->>1)::numeric)
      from j, jsonb_array_elements(doc->'data'->'rows') r"

# What the question keeps of the metric: a reference to it, not the formula.
mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
echo "-- Its summary, as Metabase stores it:"
json_sql "$mb_tmp/card.json" "
    select a::text from j, jsonb_path_query(doc->'dataset_query', 'strict \$.** ? (@.type() == \"array\")') a
     where a->>0 = 'metric'"
