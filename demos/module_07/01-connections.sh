#!/usr/bin/env bash
# Clip 7.1. Connects pachadataformation twice more in Metabase, once per service, each time
# under the role that ./setup/roles.sh created for it:
#   "Données du planning"       as lecture_planning     (stage, rooms and places)
#   "Données de la facturation" as lecture_facturation  (inscription, payment modes)
# The passwords come from .env and travel in a file only this user can read. A connection of
# the same name is left as it is. Then waits for the first sync and prints, for each
# connection, the tables Metabase found.
# Usage: ./demos/module_07/01-connections.sh (after ./setup/roles.sh)
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"
[ -n "${LECTURE_PLANNING_PASSWORD:-}" ] && [ -n "${LECTURE_FACTURATION_PASSWORD:-}" ] \
    || { echo "No password of lecture_planning or lecture_facturation in .env: run ./setup/roles.sh first." >&2; exit 1; }

connect() {
    local name=$1 user=$2 password=$3 code id
    mb_call GET /api/database "$tmp/databases.json" >/dev/null
    id=$(json_sql "$tmp/databases.json" "
        select d->>'id' from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
         where d->>'name' = $(sql_text "$name")")
    if [ -z "$id" ]; then
        printf '{"engine":"postgres","name":%s,"details":{"host":"db","port":5432,"dbname":"pachadataformation","user":%s,"password":%s,"ssl":false}}' \
            "$(json_text "$name")" "$(json_text "$user")" "$(json_text "$password")" > "$tmp/db.json"
        code=$(mb_call POST /api/database "$tmp/new.json" "$tmp/db.json")
        rm -f "$tmp/db.json"
        [ "$code" = 200 ] || { echo "Metabase did not connect \"$name\" (HTTP $code)" >&2; exit 1; }
        id=$(json_sql "$tmp/new.json" "select doc->>'id' from j")
        echo "\"$name\" connected as $user (id $id)." >&2
    else
        echo "\"$name\" was already connected (id $id)." >&2
    fi
    printf '%s\n' "$id"
}
pl=$(connect "Données du planning" lecture_planning "$LECTURE_PLANNING_PASSWORD")
fa=$(connect "Données de la facturation" lecture_facturation "$LECTURE_FACTURATION_PASSWORD")

# The first sync runs in the background: wait until both connections have their tables.
for db in $pl $fa; do
    for _ in $(seq 1 30); do
        mb_call GET "/api/database/$db/metadata" "$tmp/meta.json" >/dev/null
        [ "$(json_sql "$tmp/meta.json" "select jsonb_array_length(coalesce(doc->'tables', '[]')) > 0 from j")" = t ] && break
        sleep 2
    done
    json_sql "$tmp/meta.json" "
        select doc->>'name' || ': ' || count(*) || ' tables, ' || string_agg(t->>'schema' || '.' || (t->>'name'), ', ' order by t->>'schema', t->>'name')
          from j, jsonb_array_elements(doc->'tables') t group by doc->>'name'"
done
