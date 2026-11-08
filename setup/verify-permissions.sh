#!/usr/bin/env bash
# Verifies the permissions of a group of Metabase (module 7) against the lines of a reference
# file, then tries them under an API key of that group.
# Usage: ./setup/verify-permissions.sh REFERENCE.sql
# The first lines of REFERENCE.sql say what is expected:
#   -- check: group Planning                           the group, by its name
#   -- check: connection lecture_planning              the connection of the group, found by
#                                                      the PostgreSQL role it reads as; the
#                                                      group must create queries there with the
#                                                      query builder only, and nowhere else
#   -- check: allowed stage.session                    a table of that connection: its count of
#                                                      rows, asked under the key of the group,
#                                                      must equal the query of REFERENCE.sql
#   -- check: refused lecture_facturation inscription.facture
#                                                      a table of another connection, which the
#                                                      group must not query
#   -- check: hidden collection Facturation            a collection at the root, which neither
#                                                      the group nor All Users may open
# The steps:
# 1. the group exists and has at least one account (an API key is not an account);
# 2. the permission graph (GET /api/permissions/graph): All Users creates no query on any
#    connection, the group creates queries on its connection with the query builder only (no
#    SQL), and on no other connection;
# 3. the collection graph (GET /api/collection/graph): neither All Users nor the group can open
#    the hidden collection;
# 4. a temporary API key is made in the group (POST /api/api-key), and the four things are
#    tried under it, as a member of the group and of All Users only: the count of the allowed
#    table (POST /api/dataset) gives the rows of REFERENCE.sql, the refused table and a SQL
#    query on the connection of the group are refused, and GET /api/collection does not list
#    the hidden collection. The key is deleted at the end, whatever happens.
# Exit codes, as check.sh: 0 pass; 1 the lab, the API key, the reference file; 2 the group,
# its account or one of the connections is missing; 3 a permission differs from the one asked.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tmp=$(mktemp -d)
key_id=
cleanup() {
    if [ -n "$key_id" ]; then mb_call DELETE "/api/api-key/$key_id" "$tmp/out.json" >/dev/null; fi
    rm -rf "$tmp"
}
trap cleanup EXIT

verdict() {
    printf '%s\n' "$1"
    case "$1" in
        PASS*) exit 0 ;;
        'FAIL missing'*|'FAIL error'*) exit 2 ;;
        'FAIL rows'*) exit 3 ;;
        *) exit 1 ;;
    esac
}

ref=${1:-}
[ -n "$ref" ] && [ -f "$ref" ] || verdict "FAIL lab: usage: $0 REFERENCE.sql"
line() { head -10 "$ref" | sed -n "s/^-- check: $1  *//p" | tr -d '\r' | head -1; }
group=$(line group)
role=$(line connection)
allowed=$(line allowed)
refused=$(line refused)
hidden=$(line 'hidden collection')
[ -n "$group" ] && [ -n "$role" ] && [ -n "$allowed" ] && [ -n "$refused" ] && [ -n "$hidden" ] \
    || verdict "FAIL lab: $ref lacks one of the lines group, connection, allowed, refused, hidden collection"
refused_role=${refused%% *}
refused_table=${refused#* }

lab_running "$c" || verdict "FAIL lab: the container $c (PostgreSQL) is not running; start the lab with ./setup/install.sh"
lab_running "$mbc" || verdict "FAIL lab: the container $mbc (Metabase) is not running; start the lab with ./setup/install.sh"
mb_healthy || verdict "FAIL lab: Metabase does not answer on $mb_url/api/health"
[ -n "${MB_API_KEY:-}" ] || verdict "FAIL lab: no API key in .env (MB_API_KEY); make one with ./setup/api-key.sh"

# The connections, by the role they read pachadataformation as.
code=$(mb_call GET /api/database "$tmp/databases.json")
[ "$code" = 200 ] || verdict "FAIL lab: Metabase refuses the API key of .env (HTTP $code)"
db_of() {
    json_sql "$tmp/databases.json" "
        select d->>'id' || '|' || (d->>'name')
          from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
         where d->'details'->>'dbname' = 'pachadataformation' and d->'details'->>'user' = $(sql_text "$1")
         order by (d->>'id')::int limit 1"
}
IFS='|' read -r db db_name < <(db_of "$role")
[ -n "${db:-}" ] || verdict "FAIL missing: no connection of Metabase reads pachadataformation as $role (clip 7.1: ./setup/roles.sh, then the connection)"
IFS='|' read -r rdb rdb_name < <(db_of "$refused_role")
[ -n "${rdb:-}" ] || verdict "FAIL missing: no connection of Metabase reads pachadataformation as $refused_role (clip 7.1)"
echo "Connection of the group: \"$db_name\" (id $db, as $role); refused: \"$rdb_name\" (id $rdb, as $refused_role)."

# 1. The group and its accounts.
mb_call GET /api/permissions/group "$tmp/groups.json" >/dev/null
all=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'magic_group_type' = 'all-internal-users'")
gid=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'name' = $(sql_text "$group")")
[ -n "$gid" ] || verdict "FAIL missing: no group named \"$group\" (Administration > People > Groups)"
mb_call GET "/api/permissions/group/$gid" "$tmp/group.json" >/dev/null
accounts=$(json_sql "$tmp/group.json" "
    select count(*) from j, jsonb_array_elements(coalesce(doc->'members', '[]')) m where m->>'type' = 'personal'")
[ "${accounts:-0}" -ge 1 ] || verdict "FAIL missing: the group \"$group\" has no account; add one (Administration > People)"
echo "Group \"$group\" (id $gid): $accounts account(s)."

# 2. The permission graph. A right not written in the graph is "no"; an object is a right set
# schema by schema (granular), which is the query builder only.
mb_call GET /api/permissions/graph "$tmp/graph.json" >/dev/null
{ printf '{"g":'; cat "$tmp/graph.json"; printf ',"d":'; cat "$tmp/databases.json"; printf '}'; } > "$tmp/both.json"
problem=$(json_sql "$tmp/both.json" "
    with dbs as (
        select d->>'id' as id, d->>'name' as name
          from j, jsonb_array_elements(case jsonb_typeof(doc->'d') when 'array' then doc->'d' else doc->'d'->'data' end) d
         where not coalesce((d->>'is_sample')::boolean, false)),
    rights as (
        select g.who, g.gid, dbs.id, dbs.name,
               (select doc->'g'->'groups'->g.gid->dbs.id->'create-queries' from j) as cq
          from dbs, (values ('All Users', $(sql_text "$all")), ($(sql_text "$group"), $(sql_text "$gid"))) g(who, gid))
    select coalesce(string_agg(msg, E'\n' order by ord), '')
      from (select case
                when who = 'All Users' and cq is not null
                    then format('FAIL rows: All Users can still create queries on \"%s\" (%s): restrict All Users first (create queries: no)', name, cq #>> '{}')
                when who <> 'All Users' and id = $(sql_text "$db") and cq is null
                    then format('FAIL rows: the group \"%s\" cannot create queries on \"%s\"; give it the query builder', who, name)
                when who <> 'All Users' and id = $(sql_text "$db") and cq #>> '{}' = 'query-builder-and-native'
                    then format('FAIL rows: the group \"%s\" can still write SQL on \"%s\"; give it the query builder only', who, name)
                when who <> 'All Users' and id <> $(sql_text "$db") and cq is not null
                    then format('FAIL rows: the group \"%s\" can create queries on \"%s\" (%s), which is not its connection', who, name, cq #>> '{}')
                end as msg,
                case when who = 'All Users' then 0 else 1 end * 1000 + id::int as ord
              from rights) x
     where msg is not null")
[ -z "$problem" ] || verdict "$(printf '%s\n' "$problem" | head -1)"
echo "PASS: All Users creates no query; \"$group\" uses the query builder on \"$db_name\" only"

# 3. The collection graph.
mb_call GET /api/collection "$tmp/collections.json" >/dev/null
cid=$(json_sql "$tmp/collections.json" "
    select c->>'id' from j, jsonb_array_elements(doc) c
     where c->>'name' = $(sql_text "$hidden") and c->>'location' = '/' and c->>'personal_owner_id' is null
       and not coalesce((c->>'archived')::boolean, false) order by (c->>'id')::int limit 1")
[ -n "$cid" ] || verdict "FAIL missing: no collection \"$hidden\" at the root (module 2 makes it)"
mb_call GET /api/collection/graph "$tmp/cgraph.json" >/dev/null
for pair in "All Users:$all" "$group:$gid"; do
    who=${pair%%:*} id=${pair##*:}
    access=$(json_sql "$tmp/cgraph.json" "select coalesce(doc->'groups'->$(sql_text "$id")->>$(sql_text "$cid"), 'none') from j")
    [ "$access" = none ] || verdict "FAIL rows: $who can open the collection \"$hidden\" ($access); set it to no access"
done
echo "PASS: neither All Users nor \"$group\" can open the collection \"$hidden\""

# 4. The same, tried under a temporary key of the group.
printf '{"name":%s,"group_id":%s}' "$(json_text "check.sh 07 $(date '+%Y-%m-%d %H:%M:%S')")" "$gid" > "$tmp/key-request.json"
code=$(mb_call POST /api/api-key "$tmp/key.json" "$tmp/key-request.json")
[ "$code" = 200 ] || verdict "FAIL lab: Metabase did not make the temporary API key of the group (HTTP $code)"
key_id=$(json_sql "$tmp/key.json" "select doc->>'id' from j")
group_key=$(json_sql "$tmp/key.json" "select doc->>'unmasked_key' from j")
rm -f "$tmp/key.json"
as_group() { MB_API_KEY=$group_key mb_call "$@"; }
table_id() {
    mb_call GET "/api/database/$1/metadata" "$tmp/meta-$1.json" >/dev/null
    json_sql "$tmp/meta-$1.json" "
        select x->>'id' from j, jsonb_array_elements(doc->'tables') x
         where x->>'schema' || '.' || (x->>'name') = $(sql_text "$2")"
}
t_allowed=$(table_id "$db" "$allowed")
[ -n "$t_allowed" ] || verdict "FAIL missing: Metabase does not see $allowed in \"$db_name\" (sync the connection)"
t_refused=$(table_id "$rdb" "$refused_table")
[ -n "$t_refused" ] || verdict "FAIL missing: Metabase does not see $refused_table in \"$rdb_name\" (sync the connection)"

printf '{"database":%s,"type":"query","query":{"source-table":%s,"aggregation":[["count"]]}}' "$db" "$t_allowed" > "$tmp/q.json"
code=$(as_group POST /api/dataset "$tmp/r.json" "$tmp/q.json")
got=$(json_sql "$tmp/r.json" "select doc->'data'->'rows'->0->>0 from j" 2>/dev/null)
[ -n "$got" ] || verdict "FAIL rows: the group cannot count the rows of $allowed on \"$db_name\" (HTTP $code)"
want=$(sed 's/;[[:space:]]*$//' "$ref" | tr -d '\r' | psql_lab -d pachadataformation -q -At -v ON_ERROR_STOP=1)
[ "$got" = "$want" ] || verdict "FAIL rows: the group counts $got rows in $allowed, the reference $want"
echo "PASS: the group counts $got rows in $allowed with the query builder, like the reference"

printf '{"database":%s,"type":"query","query":{"source-table":%s,"aggregation":[["count"]]}}' "$rdb" "$t_refused" > "$tmp/q.json"
code=$(as_group POST /api/dataset "$tmp/r.json" "$tmp/q.json")
[ "$code" = 403 ] || verdict "FAIL rows: the group can query $refused_table on \"$rdb_name\" (HTTP $code); it must be refused"
echo "PASS: $refused_table on \"$rdb_name\" refused to the group (HTTP 403)"

printf '{"database":%s,"type":"native","native":{"query":"select 1"}}' "$db" > "$tmp/q.json"
code=$(as_group POST /api/dataset "$tmp/r.json" "$tmp/q.json")
[ "$code" = 403 ] || verdict "FAIL rows: the group can run SQL on \"$db_name\" (HTTP $code); give it the query builder only"
echo "PASS: SQL on \"$db_name\" refused to the group (HTTP 403)"

as_group GET /api/collection "$tmp/seen.json" >/dev/null
seen=$(json_sql "$tmp/seen.json" "select count(*) from j, jsonb_array_elements(doc) c where c->>'id' = $(sql_text "$cid")")
[ "$seen" = 0 ] || verdict "FAIL rows: the group sees the collection \"$hidden\""
verdict "PASS: the group \"$group\" queries its connection with the query builder only, and does not see \"$hidden\""
