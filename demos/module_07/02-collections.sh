#!/usr/bin/env bash
# Clip 7.2. Closes the collection "Facturation" (module 2) to everyone but its service:
# "All Users" gets no access to it, the group "Facturation" (01-groups.sh) may change it
# (curate). The other collections keep their permissions. A saved question is read by whoever
# can open its collection, whatever their right to create queries: the open-source edition has
# no "Blocked" to stop it, so the collection is the only lock on what is already built.
# Then makes the account "Compte Direction" (direction@pachadata.example), in All Users only,
# for the check of the clip and for clip 7.3; its password is drawn at random into .env
# (MB_DIRECTION_PASSWORD) when it is empty there, never printed.
# Usage: ./demos/module_07/02-collections.sh (after 01-groups.sh)
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

mb_call GET /api/collection "$tmp/collections.json" >/dev/null
coll=$(json_sql "$tmp/collections.json" "
    select c->>'id' from j, jsonb_array_elements(doc) c
     where c->>'name' = 'Facturation' and c->>'location' = '/' and c->>'personal_owner_id' is null
       and not coalesce((c->>'archived')::boolean, false) order by (c->>'id')::int limit 1")
[ -n "$coll" ] || { echo "No collection \"Facturation\" at the root: module 2 makes it (demos/module_02/02-payments-by-mode.sh)." >&2; exit 1; }
mb_call GET /api/permissions/group "$tmp/groups.json" >/dev/null
all=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'magic_group_type' = 'all-internal-users'")
g=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'name' = 'Facturation'")
[ -n "$g" ] || { echo "No group \"Facturation\": run 01-groups.sh first." >&2; exit 1; }

# The graph of the collections, changed for this collection only.
mb_call GET /api/collection/graph "$tmp/graph.json" >/dev/null
json_sql "$tmp/graph.json" "
    select jsonb_build_object('revision', doc->'revision', 'groups', jsonb_build_object(
             $(sql_text "$all"), jsonb_build_object($(sql_text "$coll"), 'none'),
             $(sql_text "$g"), jsonb_build_object($(sql_text "$coll"), 'write')))
      from j" > "$tmp/graph-new.json"
code=$(mb_call PUT /api/collection/graph "$tmp/graph-out.json" "$tmp/graph-new.json")
[ "$code" = 200 ] || { echo "Metabase refused the collection permissions (HTTP $code): $(head -c 300 "$tmp/graph-out.json")" >&2; exit 1; }
echo "Collection \"Facturation\" (id $coll): All Users none, Facturation write."

umask 077
grep -q '^MB_DIRECTION_PASSWORD=' .env || printf 'MB_DIRECTION_PASSWORD=\n' >> .env
NEW_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true) awk '
    /^MB_DIRECTION_PASSWORD=$/ { print "MB_DIRECTION_PASSWORD=" ENVIRON["NEW_PW"]; next } { print }' .env > .env.new
mv .env.new .env
umask 022
password=$(sed -n 's/^MB_DIRECTION_PASSWORD=//p' .env | tail -1)
mb_call GET "/api/user?query=direction%40pachadata.example" "$tmp/users.json" >/dev/null
u=$(json_sql "$tmp/users.json" "select u->>'id' from j, jsonb_array_elements(doc->'data') u where u->>'email' = 'direction@pachadata.example'")
if [ -z "$u" ]; then
    printf '{"first_name":"Compte","last_name":"Direction","email":"direction@pachadata.example","password":%s}' \
        "$(json_text "$password")" > "$tmp/user.json"
    code=$(mb_call POST /api/user "$tmp/user-new.json" "$tmp/user.json")
    rm -f "$tmp/user.json"
    [ "$code" = 200 ] || { echo "Metabase did not create the account (HTTP $code)" >&2; exit 1; }
    u=$(json_sql "$tmp/user-new.json" "select doc->>'id' from j")
    echo "Account direction@pachadata.example created (id $u), in All Users only, password in .env (MB_DIRECTION_PASSWORD)."
else
    echo "Account direction@pachadata.example already there (id $u)."
fi
mb_call GET /api/collection/graph "$tmp/graph.json" >/dev/null
{ printf '{"g":'; cat "$tmp/graph.json"; printf ',"n":'; cat "$tmp/groups.json"; printf '}'; } > "$tmp/both.json"
json_sql "$tmp/both.json" "
    select format('%-15s %s', n->>'name', coalesce(doc->'g'->'groups'->(n->>'id')->>$(sql_text "$coll"), 'none'))
      from j, jsonb_array_elements(doc->'n') n order by (n->>'id')::int"
