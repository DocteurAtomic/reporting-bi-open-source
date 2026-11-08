#!/usr/bin/env bash
# Clip 4.4. Three charts to avoid, saved in the collection "Module 04" and run: the invoices of
# 2011 by month in a pie chart, with the total in the middle; the same months with the number
# of invoices and their amount before tax, which Metabase draws on two y-axes; the sessions by
# year in bars whose y-axis starts at 250 instead of zero.
# Usage: ./demos/module_04/04-charts-to-avoid.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_04
coll=$(mb_collection "Module 04")
for f in 04-invoices-2011-pie 04-invoices-2011-two-axes 04-sessions-by-year-truncated; do
    id=$(mb_save_card "$d/$f.json" "$coll")
    mb_run_card "$id" "$mb_tmp/answer.json"
    mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
    echo "-- $(json_sql "$mb_tmp/card.json" "select '\"' || (doc->>'name') || '\" (id ' || (doc->>'id') || '), display ' || (doc->>'display') || ', settings ' || (doc->'visualization_settings')::text from j"):"
    mb_rows "$mb_tmp/answer.json"
done
