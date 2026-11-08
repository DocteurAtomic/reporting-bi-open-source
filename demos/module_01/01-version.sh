#!/usr/bin/env bash
# Clip 1.1: which Metabase runs in the lab, and which edition. Reads GET /api/session/properties,
# which answers without a key: the version (tag, build date) and the paid features of the
# instance (token-features), all off in the open-source edition. Read only.
# Usage, from the root of the clone: ./demos/module_01/01-version.sh
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsS --max-time 10 "$mb_url/api/session/properties" -o "$tmp/properties.json" \
    || { echo "Metabase does not answer on $mb_url." >&2; exit 1; }
json_sql "$tmp/properties.json" "
select 'version ' || (doc->'version'->>'tag') || ', built on ' || (doc->'version'->>'date') from j
union all
select 'paid features on: ' || count(*) filter (where f.value = 'true'::jsonb) || ' of ' || count(*)
  from j, jsonb_each(doc->'token-features') f"
