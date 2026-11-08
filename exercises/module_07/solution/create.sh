#!/usr/bin/env bash
# The solution of exercise 07, through the API, in the order of the exercise:
# 1. All Users creates no query on any connection;
# 2. the group "Planning" (made if missing) gets the query builder only on the connection read
#    as lecture_planning, and nothing on the others;
# 3. the account "Compte Planning" (planning@pachadata.example, made if missing) joins it; its
#    password is drawn at random into .env (MB_PLANNING_PASSWORD) when it is empty, never shown;
# 4. neither All Users nor Planning can open the collection "Facturation".
# It needs the connections of clip 7.1 (./setup/roles.sh, then
# ./demos/module_07/01-connections.sh). Used by the continuous integration before
# ./setup/check.sh 07; you can run it to see the solution in Metabase.
# Usage: ./exercises/module_07/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"
fail() { echo "$*" >&2; exit 1; }

mb_call GET /api/database "$tmp/databases.json" >/dev/null
pl=$(json_sql "$tmp/databases.json" "
    select d->>'id' from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
     where d->'details'->>'dbname' = 'pachadataformation' and d->'details'->>'user' = 'lecture_planning'
     order by (d->>'id')::int limit 1")
[ -n "$pl" ] || fail "No connection as lecture_planning: run ./setup/roles.sh, then ./demos/module_07/01-connections.sh."
mb_call GET /api/permissions/group "$tmp/groups.json" >/dev/null
all=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'magic_group_type' = 'all-internal-users'")
g=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'name' = 'Planning'")
if [ -z "$g" ]; then
    echo '{"name":"Planning"}' > "$tmp/group.json"
    mb_call POST /api/permissions/group "$tmp/group-new.json" "$tmp/group.json" >/dev/null
    g=$(json_sql "$tmp/group-new.json" "select doc->>'id' from j")
fi
[ -n "$g" ] || fail "Metabase did not create the group Planning."

# 1 and 2, in one graph: create-queries for each connection of the graph.
mb_call GET /api/permissions/graph "$tmp/graph.json" >/dev/null
json_sql "$tmp/graph.json" "
    select jsonb_build_object('revision', doc->'revision', 'groups', jsonb_build_object(
             $(sql_text "$all"), (select jsonb_object_agg(db, jsonb_build_object('view-data', 'unrestricted', 'create-queries', 'no'))
                                    from jsonb_object_keys(doc->'groups'->$(sql_text "$all")) db),
             $(sql_text "$g"), (select jsonb_object_agg(db, jsonb_build_object('view-data', 'unrestricted', 'create-queries',
                                         case when db = $(sql_text "$pl") then 'query-builder' else 'no' end))
                                  from jsonb_object_keys(doc->'groups'->$(sql_text "$all")) db)))
      from j" > "$tmp/graph-new.json"
code=$(mb_call PUT /api/permissions/graph "$tmp/out.json" "$tmp/graph-new.json")
[ "$code" = 200 ] || fail "Metabase refused the permissions (HTTP $code)."
echo "All Users: no query; Planning: query builder on the connection $pl only."

# 3. The account.
umask 077
grep -q '^MB_PLANNING_PASSWORD=' .env || printf 'MB_PLANNING_PASSWORD=\n' >> .env
NEW_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true) awk '
    /^MB_PLANNING_PASSWORD=$/ { print "MB_PLANNING_PASSWORD=" ENVIRON["NEW_PW"]; next } { print }' .env > .env.new
mv .env.new .env
umask 022
password=$(sed -n 's/^MB_PLANNING_PASSWORD=//p' .env | tail -1)
mb_call GET "/api/user?query=planning%40pachadata.example" "$tmp/users.json" >/dev/null
u=$(json_sql "$tmp/users.json" "select u->>'id' from j, jsonb_array_elements(doc->'data') u where u->>'email' = 'planning@pachadata.example'")
if [ -z "$u" ]; then
    printf '{"first_name":"Compte","last_name":"Planning","email":"planning@pachadata.example","password":%s,"user_group_memberships":[{"id":%s},{"id":%s}]}' \
        "$(json_text "$password")" "$all" "$g" > "$tmp/user.json"
    code=$(mb_call POST /api/user "$tmp/user-new.json" "$tmp/user.json")
    rm -f "$tmp/user.json"
    [ "$code" = 200 ] || fail "Metabase did not create the account (HTTP $code)."
    u=$(json_sql "$tmp/user-new.json" "select doc->>'id' from j")
else
    printf '{"group_id":%s,"user_id":%s}' "$g" "$u" > "$tmp/member.json"
    mb_call POST /api/permissions/membership "$tmp/out.json" "$tmp/member.json" >/dev/null
fi
echo "Account planning@pachadata.example (id $u) in Planning."

# 4. The collection Facturation, closed to All Users and Planning.
mb_call GET /api/collection "$tmp/collections.json" >/dev/null
coll=$(json_sql "$tmp/collections.json" "
    select c->>'id' from j, jsonb_array_elements(doc) c
     where c->>'name' = 'Facturation' and c->>'location' = '/' and c->>'personal_owner_id' is null
       and not coalesce((c->>'archived')::boolean, false) order by (c->>'id')::int limit 1")
[ -n "$coll" ] || fail "No collection Facturation at the root (module 2 makes it)."
mb_call GET /api/collection/graph "$tmp/cgraph.json" >/dev/null
json_sql "$tmp/cgraph.json" "
    select jsonb_build_object('revision', doc->'revision', 'groups', jsonb_build_object(
             $(sql_text "$all"), jsonb_build_object($(sql_text "$coll"), 'none'),
             $(sql_text "$g"), jsonb_build_object($(sql_text "$coll"), 'none')))
      from j" > "$tmp/cgraph-new.json"
code=$(mb_call PUT /api/collection/graph "$tmp/out.json" "$tmp/cgraph-new.json")
[ "$code" = 200 ] || fail "Metabase refused the collection permissions (HTTP $code)."
echo "Collection Facturation (id $coll): no access for All Users and Planning."
