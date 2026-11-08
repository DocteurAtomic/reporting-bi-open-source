#!/usr/bin/env bash
# Clip 7.1. The data permissions of the open-source edition, in the order the clip sets them:
# 1. "All Users", the group every account belongs to, loses the right to create queries on
#    every connection (create-queries "no"); it keeps view-data "unrestricted", the only value
#    the open-source edition has, so its members still read the saved questions of the
#    collections they can open;
# 2. the group "Facturation" (made if missing) gets the query builder and SQL on the connection
#    "Données de la facturation", and nothing on the others;
# 3. the account "Compte Facturation" (facturation@pachadata.example, made if missing) joins
#    the group. Its password is drawn at random into .env (MB_FACTURATION_PASSWORD) when it is
#    empty there, never printed.
# Permissions add up across groups: a member of two groups gets the larger right of the two,
# which is why All Users goes first. Prints the permissions of both groups at the end.
# Usage: ./demos/module_07/01-groups.sh (after 01-connections.sh)
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

db_id() {
    mb_call GET /api/database "$tmp/databases.json" >/dev/null
    json_sql "$tmp/databases.json" "
        select d->>'id' from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
         where d->>'name' = $(sql_text "$1")"
}
group_id() {
    mb_call GET /api/permissions/group "$tmp/groups.json" >/dev/null
    json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'name' = $(sql_text "$1")"
}
# put_graph SQL: the body of PUT /api/permissions/graph, built by SQL from the current graph
# (the document j); the revision of the graph is the one just read, or Metabase answers 409.
put_graph() {
    mb_call GET /api/permissions/graph "$tmp/graph.json" >/dev/null
    json_sql "$tmp/graph.json" "$1" > "$tmp/graph-new.json"
    code=$(mb_call PUT /api/permissions/graph "$tmp/graph-out.json" "$tmp/graph-new.json")
    [ "$code" = 200 ] || { echo "Metabase refused the permissions (HTTP $code): $(head -c 300 "$tmp/graph-out.json")" >&2; exit 1; }
}

fa=$(db_id "Données de la facturation")
[ -n "$fa" ] || { echo "No connection \"Données de la facturation\": run 01-connections.sh first." >&2; exit 1; }
mb_call GET /api/permissions/group "$tmp/groups.json" >/dev/null
all=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'magic_group_type' = 'all-internal-users'")

# 1. All Users: no query on any connection.
put_graph "
    select jsonb_build_object('revision', doc->'revision', 'groups', jsonb_build_object($(sql_text "$all"),
             (select jsonb_object_agg(db, jsonb_build_object('view-data', 'unrestricted', 'create-queries', 'no'))
                from jsonb_object_keys(doc->'groups'->$(sql_text "$all")) db)))
      from j"
echo "All Users: create-queries no on every connection."

# 2. The group Facturation: the query builder and SQL on its connection, nothing elsewhere.
g=$(group_id Facturation)
if [ -z "$g" ]; then
    echo '{"name":"Facturation"}' > "$tmp/group.json"
    mb_call POST /api/permissions/group "$tmp/group-new.json" "$tmp/group.json" >/dev/null
    g=$(json_sql "$tmp/group-new.json" "select doc->>'id' from j")
    echo "Group \"Facturation\" created (id $g)."
fi
put_graph "
    select jsonb_build_object('revision', doc->'revision', 'groups', jsonb_build_object($(sql_text "$g"),
             (select jsonb_object_agg(db, jsonb_build_object('view-data', 'unrestricted', 'create-queries',
                        case when db = $(sql_text "$fa") then 'query-builder-and-native' else 'no' end))
                from jsonb_object_keys(doc->'groups'->$(sql_text "$all")) db)))
      from j"
echo "Facturation: query-builder-and-native on \"Données de la facturation\" (id $fa), no elsewhere."

# 3. The account, in the group.
umask 077
grep -q '^MB_FACTURATION_PASSWORD=' .env || printf 'MB_FACTURATION_PASSWORD=\n' >> .env
NEW_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true) awk '
    /^MB_FACTURATION_PASSWORD=$/ { print "MB_FACTURATION_PASSWORD=" ENVIRON["NEW_PW"]; next } { print }' .env > .env.new
mv .env.new .env
umask 022
password=$(sed -n 's/^MB_FACTURATION_PASSWORD=//p' .env | tail -1)
mb_call GET "/api/user?query=facturation%40pachadata.example" "$tmp/users.json" >/dev/null
u=$(json_sql "$tmp/users.json" "select u->>'id' from j, jsonb_array_elements(doc->'data') u where u->>'email' = 'facturation@pachadata.example'")
if [ -z "$u" ]; then
    printf '{"first_name":"Compte","last_name":"Facturation","email":"facturation@pachadata.example","password":%s,"user_group_memberships":[{"id":%s},{"id":%s}]}' \
        "$(json_text "$password")" "$all" "$g" > "$tmp/user.json"
    code=$(mb_call POST /api/user "$tmp/user-new.json" "$tmp/user.json")
    rm -f "$tmp/user.json"
    [ "$code" = 200 ] || { echo "Metabase did not create the account (HTTP $code)" >&2; exit 1; }
    u=$(json_sql "$tmp/user-new.json" "select doc->>'id' from j")
    echo "Account facturation@pachadata.example created (id $u), password in .env (MB_FACTURATION_PASSWORD)."
else
    echo "Account facturation@pachadata.example already there (id $u)."
fi

mb_call GET /api/permissions/graph "$tmp/graph.json" >/dev/null
mb_call GET /api/database "$tmp/databases.json" >/dev/null
{ printf '{"g":'; cat "$tmp/graph.json"; printf ',"d":'; cat "$tmp/databases.json"; printf '}'; } > "$tmp/both.json"
json_sql "$tmp/both.json" "
    select format('%-12s %-28s %s', case k when $(sql_text "$all") then 'All Users' else 'Facturation' end, d->>'name', coalesce(p->>'create-queries', 'no'))
      from j, jsonb_each(doc->'g'->'groups') x(k, v), jsonb_each(v) y(db, p),
           jsonb_array_elements(case jsonb_typeof(doc->'d') when 'array' then doc->'d' else doc->'d'->'data' end) d
     where k in ($(sql_text "$all"), $(sql_text "$g")) and d->>'id' = db
     order by k desc, (d->>'id')::int"
