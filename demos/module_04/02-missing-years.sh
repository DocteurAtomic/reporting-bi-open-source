#!/usr/bin/env bash
# Clip 4.2. The sessions by year in a line chart whose missing values are replaced by zero:
# a copy of "Sessions par année" (clip 1.5, left as it is) saved as "Sessions par année, années
# manquantes à zéro" in the collection "Module 04". Prints the rows, which are the same eight
# years as before (Metabase adds 2013 and 2014 when it draws the line, not in the answer), then
# the chart settings read back by GET /api/card/<id>: the option of the series "count" is in
# series_settings, under the key line.missing (zero, none, or interpolate, the default).
# Usage: ./demos/module_04/02-missing-years.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_04
coll=$(mb_collection "Module 04")
id=$(mb_save_card "$d/02-sessions-by-year-zero.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Sessions par année, années manquantes à zéro\" (id $id), the rows:"
mb_rows "$mb_tmp/answer.json"
mb_call GET "/api/card/$id" "$mb_tmp/card.json" >/dev/null
echo "-- display and visualization_settings, read back:"
json_sql "$mb_tmp/card.json" "select doc->>'display', jsonb_pretty(doc->'visualization_settings') from j"
