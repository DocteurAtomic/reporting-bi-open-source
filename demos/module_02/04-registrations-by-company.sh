#!/usr/bin/env bash
# Clip 2.4. The registrations by company: from inscription to societe through contact. With
# the left joins of the query builder, the first row has no company (4,303 registrations);
# with an inner join on contact, it keeps 4,137; the column "Société", a custom column, names
# the two groups. The last state is saved as "Inscriptions par société" in the collection
# "Facturation".
# Usage: ./demos/module_02/04-registrations-by-company.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_02

mb_run_template "$d/04-registrations-by-company-default.json" "$mb_tmp/answer.json"
echo "-- Left joins, the default (first rows):"
mb_rows "$mb_tmp/answer.json" | head -4
mb_run_template "$d/04-registrations-by-company-inner.json" "$mb_tmp/answer.json"
echo "-- Inner join on contact, left join on societe (first rows):"
mb_rows "$mb_tmp/answer.json" | head -4

coll=$(mb_collection Facturation)
id=$(mb_save_card "$d/04-registrations-by-company.json" "$coll")
mb_run_card "$id" "$mb_tmp/answer.json"
echo "-- \"Inscriptions par société\" (id $id), with the column Société (first rows, and the rows without a company):"
mb_rows "$mb_tmp/answer.json" | head -4
mb_rows "$mb_tmp/answer.json" | grep -E '^Sans (contact|société) \|' || true
json_sql "$mb_tmp/answer.json" "
    select count(*) || ' rows, ' || sum((r->>1)::int) || ' registrations'
      from j, jsonb_array_elements(doc->'data'->'rows') r"
