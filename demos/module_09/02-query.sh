#!/usr/bin/env bash
# Clips 9.2 and 9.3: the query behind an answer of Metabot, read in the answer saved by
# ./bench/metabot.sh (work/metabot/<Qnn>.sse).
# Usage: ./demos/module_09/02-query.sh Qnn
#   For each question Metabot built while answering, prints its database, its source (a table,
#   or a saved question, model or metric, with its name), its summaries, its groupings and its
#   filters, in the MBQL of Metabase, shortened: the internal ids of the expressions (lib/uuid)
#   and the types are left out. This is what the link of the answer opens in the editor.
# Ask the question first, for instance: ./bench/metabot.sh Q03 (it costs one question).
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
id=${1:-}
[ -n "$id" ] || { echo "usage: $0 Qnn" >&2; exit 1; }
sse=work/metabot/$id.sse
[ -f "$sse" ] || { echo "No saved answer $sse: ask the question first, ./bench/metabot.sh $id" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The queries of the answer, one JSON object per line: the event data-generated_entity holds
# the question Metabot made, as the link of its answer opens it.
{
    echo '\set ON_ERROR_STOP on'
    echo 'create temp table e (n serial, doc jsonb);'
    echo 'copy e (doc) from stdin;'
    sed -n 's/^data: \({.*}\)\r\{0,1\}$/\1/p' "$sse" | sed 's/\\/\\\\/g'
    printf '\\.\n'
    cat <<'SQL'
create temp table q as
select n, jsonb_build_object('title', doc->'data'->>'title',
                             'database', doc->'data'->'query'->'query'->'database',
                             'stage', doc->'data'->'query'->'query'->'stages'->0) as o
  from e
 where doc->>'type' = 'data-generated_entity' and doc->'data'->'query'->'query' is not null;
-- An answer without a link to a question (Metabot gave the number in its text only): the
-- queries it ran are in its last event data-state.
insert into q
select e.n, jsonb_build_object('title', '(no link: query read in the state of the conversation)',
                               'database', x.v->'database', 'stage', x.v->'stages'->0)
  from e, jsonb_each(e.doc->'data'->'queries') x(k, v)
 where not exists (select from q)
   and e.n = (select max(n) from e where doc->>'type' = 'data-state');
select o from q order by n;
SQL
} | psql_lab -d postgres -q -At > "$tmp/queries.jsonl"
[ -s "$tmp/queries.jsonl" ] || { echo "$id: Metabot built no question in this answer."; exit 0; }

mb_call GET /api/database "$tmp/databases.json" >/dev/null
n=0
while IFS= read -r line; do
    n=$((n + 1))
    printf '%s\n' "$line" > "$tmp/q.json"
    # The names of the saved questions, models and metrics the query uses.
    names=
    for card in $(json_sql "$tmp/q.json" "
            select distinct v from j, lateral (
                select doc->'stage'->>'source-card' as v
                union all
                select a->>-1 from jsonb_path_query(doc->'stage', 'strict \$.** ? (@.type() == \"array\")') a
                 where a->>0 = 'metric') x
             where v ~ '^[0-9]+\$'"); do
        mb_call GET "/api/card/$card" "$tmp/card.json" >/dev/null
        names="$names$(json_sql "$tmp/card.json" "select format('    card %s: %s \"%s\"', doc->>'id', doc->>'type', doc->>'name') from j")"$'\n'
    done
    json_sql "$tmp/q.json" "
        with s as (select doc->'stage' as st from j)
        select format('%s. \"%s\", database %s', $n, doc->>'title', doc->>'database') from j
        union all
        select format('    %s: %s', k,
                      regexp_replace(regexp_replace(v::text, '\"(lib/uuid|base-type|effective-type|lib/type)\": \"[^\"]*\"(, )?', '', 'g'),
                                     ', \}', '}', 'g'))
          from s, jsonb_each(st) x(k, v) where k not in ('lib/type')"
    [ -n "$names" ] && printf '%s' "$names"
    # The tables and the fields given by their id.
    for t in $(json_sql "$tmp/q.json" "
            select distinct v::text from j, jsonb_path_query(doc->'stage', 'lax \$.**.\"source-table\"') v
             where jsonb_typeof(v) = 'number'"); do
        mb_call GET "/api/table/$t" "$tmp/table.json" >/dev/null
        json_sql "$tmp/table.json" "select format('    table %s: %s.%s', doc->>'id', doc->>'schema', doc->>'name') from j"
    done
    for f in $(json_sql "$tmp/q.json" "
            select distinct a->>-1 from j, jsonb_path_query(doc->'stage', 'strict \$.** ? (@.type() == \"array\")') a
             where a->>0 = 'field' and jsonb_typeof(a->-1) = 'number'"); do
        mb_call GET "/api/field/$f" "$tmp/field.json" >/dev/null
        json_sql "$tmp/field.json" "select format('    field %s: %s.%s.%s', doc->>'id', doc->'table'->>'schema', doc->'table'->>'name', doc->>'name') from j"
    done
done < "$tmp/queries.jsonl"
echo "Databases: $(json_sql "$tmp/databases.json" "select string_agg((d->>'id') || ' ' || (d->>'name'), ', ' order by (d->>'id')::int) from j, jsonb_array_elements(doc->'data') d")"
