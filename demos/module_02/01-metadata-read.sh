#!/usr/bin/env bash
# Clip 2.1. What Metabase read from the database at the sync, without changing anything: the
# primary keys and the foreign keys it found, the targets of the two columns of the key of
# stage.session to stage.stagelangue, the hidden tables, and the question "sessions by stage
# title" through the foreign key of session (an implicit join), which fails while stageid
# points to a text column.
# Run it before and after ./demos/module_02/01-metadata.sh.
# Usage: ./demos/module_02/01-metadata-read.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
db=$(mb_db_id)
mb_call GET "/api/database/$db/metadata?include_hidden=true" "$mb_tmp/metadata.json" >/dev/null
json_sql "$mb_tmp/metadata.json" "
    with t as (select x as tbl from j, jsonb_array_elements(doc->'tables') x),
         f as (select tbl->>'schema' || '.' || (tbl->>'name') || '.' || (fl->>'name') as name, fl
                 from t, jsonb_array_elements(tbl->'fields') fl),
         byid as (select (fl->>'id')::int as id, name from f)
    select 'tables: ' || (select count(*) from t)
           || ', hidden: ' || coalesce((select string_agg(tbl->>'schema' || '.' || (tbl->>'name'), ', ')
                                          from t where tbl->>'visibility_type' = 'hidden'), 'none')
    union all
    select 'primary key columns read: ' || count(*) from f where (fl->>'database_is_pk')::boolean
    union all
    select 'foreign keys (fields): ' || count(*) from f where fl->>'semantic_type' = 'type/FK'
    union all
    select 'entity keys (fields): ' || count(*) from f where fl->>'semantic_type' = 'type/PK'
    union all
    select f.name || ': ' || coalesce(fl->>'semantic_type', 'no type')
           || coalesce(' -> ' || b.name, '')
      from f left join byid b on b.id = (fl->>'fk_target_field_id')::int
     where f.name in ('stage.session.stageid', 'stage.session.languecd', 'stage.session.sessionid',
                      'inscription.inscription.sessionid')"
mb_run_template demos/module_02/01-sessions-by-title.json "$mb_tmp/answer.json"
echo "-- Sessions by stage title, through Session > Stageid:"
json_sql "$mb_tmp/answer.json" "select doc->>'status' || coalesce(': ' || split_part(doc->>'error', E'\n', 1), '') from j"
if [ "$(json_sql "$mb_tmp/answer.json" "select doc->>'status' from j")" = completed ]; then
    mb_rows "$mb_tmp/answer.json" | head -4
fi
