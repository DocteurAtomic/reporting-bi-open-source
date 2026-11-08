#!/usr/bin/env bash
# Clips 7.1 and 7.2. Signs in as one of the accounts of module 7 and prints what it gets:
# - the connections it may query (GET /api/database lists only those);
# - the collections it can open at the root;
# - the saved question "Paiements par mode" (collection "Facturation"), read by its id;
# - on each connection, the count of stage.session and of inscription.facture, asked once
#   with the query builder and once in SQL: either the number, or the refusal of Metabase
#   (HTTP 403), or the refusal of PostgreSQL (the role of the connection cannot read the table).
# The account is facturation, direction or planning; its password is read in .env
# (MB_FACTURATION_PASSWORD, MB_DIRECTION_PASSWORD, MB_PLANNING_PASSWORD), sent in a file only
# this user can read, never printed. The session is closed at the end.
# Usage: ./demos/module_07/01-try-account.sh facturation|direction|planning
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
who=${1:-}
case "$who" in facturation|direction|planning) ;; *) echo "usage: $0 facturation|direction|planning" >&2; exit 1;; esac
var=MB_${who^^}_PASSWORD
password=${!var:-}
[ -n "$password" ] || { echo "No $var in .env: the script of the clip that makes this account writes it." >&2; exit 1; }
chmod 700 "$mb_tmp"

printf '{"username":%s,"password":%s}' "$(json_text "$who@pachadata.example")" "$(json_text "$password")" > "$mb_tmp/login.json"
code=$(curl -sS --max-time 30 -o "$mb_tmp/session.json" -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    --data-binary "@$mb_tmp/login.json" "$mb_url/api/session" || true)
rm -f "$mb_tmp/login.json"
[ "$code" = 200 ] || { echo "Metabase refused the login of $who@pachadata.example (HTTP $code)." >&2; exit 1; }
session=$(json_sql "$mb_tmp/session.json" "select doc->>'id' from j")
rm -f "$mb_tmp/session.json"
as_account() {
    local args=(-sS --max-time 60 -o "$3" -w '%{http_code}' -X "$1" -H 'Content-Type: application/json')
    if [ -n "${4:-}" ]; then args+=(--data-binary "@$4"); fi
    curl "${args[@]}" -H @<(printf 'X-Metabase-Session: %s\n' "$session") "$mb_url$2" 2>/dev/null || true
}
trap 'as_account DELETE /api/session "$mb_tmp/out.json" >/dev/null; rm -rf "$mb_tmp"' EXIT
echo "Signed in as $who@pachadata.example."

as_account GET /api/database "$mb_tmp/seen.json" >/dev/null
echo "Connections it may query: $(json_sql "$mb_tmp/seen.json" "
    select coalesce(string_agg(d->>'name', ', ' order by (d->>'id')::int), '(none)')
      from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d")"
as_account GET /api/collection "$mb_tmp/collections.json" >/dev/null
echo "Collections: $(json_sql "$mb_tmp/collections.json" "
    select string_agg(c->>'name', ', ' order by c->>'name') from j, jsonb_array_elements(doc) c
     where c->>'personal_owner_id' is null and not coalesce((c->>'archived')::boolean, false)")"
card=$(mb_card_id "Paiements par mode")
if [ -n "$card" ]; then
    code=$(as_account GET "/api/card/$card" "$mb_tmp/card.json")
    if [ "$code" = 200 ]; then echo "\"Paiements par mode\": readable (HTTP 200)"
    else echo "\"Paiements par mode\": HTTP $code, $(head -c 200 "$mb_tmp/card.json")"; fi
fi

# The answer of POST /api/dataset in one line: the number, or the first line of the error.
answer() {
    local code=$1 file=$2
    if [ "$code" = 403 ] || [ "$code" = 401 ]; then echo "HTTP $code, refused by Metabase"; return; fi
    json_sql "$file" "
        select coalesce('HTTP $code, ' || (doc->'data'->'rows'->0->>0),
                        'HTTP $code, ' || split_part(coalesce(doc->>'error', doc->'via'->0->>'error', 'no answer'), E'\n', 1))
          from j" 2>/dev/null || echo "HTTP $code"
}
mb_call GET /api/database "$mb_tmp/databases.json" >/dev/null
json_sql "$mb_tmp/databases.json" "
    select d->>'id' || '|' || (d->>'name')
      from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
     where not coalesce((d->>'is_sample')::boolean, false) order by (d->>'id')::int" > "$mb_tmp/dbs.txt"
while IFS='|' read -r db name; do
    mb_call GET "/api/database/$db/metadata" "$mb_tmp/meta.json" >/dev/null
    for table in stage.session inscription.facture; do
        tid=$(json_sql "$mb_tmp/meta.json" "
            select x->>'id' from j, jsonb_array_elements(doc->'tables') x where x->>'schema' || '.' || (x->>'name') = $(sql_text "$table")")
        if [ -n "$tid" ]; then
            printf '{"database":%s,"type":"query","query":{"source-table":%s,"aggregation":[["count"]]}}' "$db" "$tid" > "$mb_tmp/q.json"
            builder=$(answer "$(as_account POST /api/dataset "$mb_tmp/r.json" "$mb_tmp/q.json")" "$mb_tmp/r.json")
        else
            builder="not in the tables of this connection"
        fi
        printf '{"database":%s,"type":"native","native":{"query":"select count(*) from %s"}}' "$db" "$table" > "$mb_tmp/q.json"
        sql=$(answer "$(as_account POST /api/dataset "$mb_tmp/r.json" "$mb_tmp/q.json")" "$mb_tmp/r.json")
        echo "\"$name\", $table: query builder $builder; SQL $sql"
    done
done < "$mb_tmp/dbs.txt"
