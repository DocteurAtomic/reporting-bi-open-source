#!/usr/bin/env bash
# Clip 1.4: the databases connected in Metabase, read with the API key of .env
# (GET /api/database). After the sample database is removed, one line: pachadataformation,
# postgres, read as lecture_bi. Read only.
# Usage, from the root of the clone: ./demos/module_01/04-databases.sh
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
code=$(mb_call GET /api/database "$tmp/databases.json")
[ "$code" = 200 ] || { echo "Metabase answers HTTP $code: is the key of .env right? (./setup/api-key.sh)" >&2; exit 1; }
json_sql "$tmp/databases.json" "
select concat_ws(' | ', d->>'id', d->>'name', d->>'engine',
                 'user ' || coalesce(d->'details'->>'user', '-'),
                 case when (d->>'is_sample')::boolean then 'sample database' end)
  from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
 order by (d->>'id')::int"
