#!/usr/bin/env bash
# Clip 4.1. One question, three ways of drawing it: the number of sessions as a number
# ("Sessions organisées"), then grouped by year of start date as bars with their values shown
# ("Sessions par année, en barres"). The line is the question "Sessions par année" of clip 1.5.
# Both questions are saved in the collection "Module 04", made if missing, and run; the rows
# are the same whatever the chart: only display and visualization_settings change.
# Usage: ./demos/module_04/01-chart-types.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_04
coll=$(mb_collection "Module 04")
for f in 01-sessions-count 01-sessions-by-year-bars; do
    id=$(mb_save_card "$d/$f.json" "$coll")
    mb_run_card "$id" "$mb_tmp/answer.json"
    mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
    echo "-- $(json_sql "$mb_tmp/card.json" "select '\"' || (doc->>'name') || '\" (id ' || (doc->>'id') || '), display ' || (doc->>'display') || ', settings ' || (doc->'visualization_settings')::text from j"):"
    mb_rows "$mb_tmp/answer.json"
done
