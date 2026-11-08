#!/usr/bin/env bash
# Clip 9.3: the sample database of Metabase, which comes back each time Metabase starts.
# Usage: ./demos/module_09/03-sample.sh [--remove]
#   Without argument, prints the databases connected in Metabase (the sample database is the
#   one marked is_sample), then the tables named ORDERS, PRODUCTS or INVOICES that the search
#   of Metabase still lists, with the id of their database: Metabot looks for its tables
#   through that search. The sample database gets a new id at each installation, so the id is
#   always read, never written in the script.
#   --remove deletes the sample database, as Admin > Databases > Sample Database > Remove
#   this database does (DELETE /api/database/<id>).
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

databases() {
    code=$(mb_call GET /api/database "$tmp/databases.json")
    [ "$code" = 200 ] || { echo "GET /api/database: HTTP $code; check the lab with ./setup/check.sh 00" >&2; exit 1; }
}
databases
sample=$(json_sql "$tmp/databases.json" "
    select d->>'id' from j, jsonb_array_elements(doc->'data') d
     where coalesce((d->>'is_sample')::boolean, false) order by (d->>'id')::int limit 1")

if [ "${1:-}" = --remove ]; then
    [ -n "$sample" ] || { echo "No sample database in Metabase: nothing to remove."; exit 0; }
    code=$(mb_call DELETE "/api/database/$sample" "$tmp/out.json")
    [ "$code" = 204 ] || [ "$code" = 200 ] || { echo "DELETE /api/database/$sample: HTTP $code" >&2; exit 1; }
    echo "Sample database (id $sample) removed."
    databases
fi

echo "Databases connected in Metabase:"
json_sql "$tmp/databases.json" "
    select format('  %s  %s (%s)%s', d->>'id', d->>'name', d->>'engine',
                  case when coalesce((d->>'is_sample')::boolean, false) then ', sample database, created '
                       || left(d->>'created_at', 19) else '' end)
      from j, jsonb_array_elements(doc->'data') d order by (d->>'id')::int"

echo "Tables of the sample database in the search of Metabase:"
connected=$(json_sql "$tmp/databases.json" "select string_agg(d->>'id', ',') from j, jsonb_array_elements(doc->'data') d")
: > "$tmp/found.txt"
for q in orders products invoices; do
    mb_call GET "/api/search?q=$q&models=table" "$tmp/search.json" >/dev/null
    json_sql "$tmp/search.json" "
        select format('  %s, database %s (%s)', r->>'name', r->>'database_id',
                      case when r->>'database_id' = any (string_to_array($(sql_text "$connected"), ','))
                           then 'connected' else 'removed, still in the search index' end)
          from j, jsonb_array_elements(doc->'data') r
         where upper(r->>'name') = upper($(sql_text "$q"))" >> "$tmp/found.txt"
done
if [ -s "$tmp/found.txt" ]; then cat "$tmp/found.txt"; else echo "  none"; fi
