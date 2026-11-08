# Sourced after setup/lib.sh by the scripts that build Metabase questions through the API
# (demos/module_NN/*.sh, exercises/module_NN/solution/create.sh).
# A question is written as a JSON template in the form POST /api/card takes (name, display,
# visualization_settings, dataset_query in MBQL), where ids are replaced by names, because the
# ids of tables and fields differ from one Metabase to another:
#   "@database"                    the id of pachadataformation in Metabase
#   "@schema.table"                the id of a table, "@inscription.facture"
#   "@schema.table.field"          the id of a field, "@inscription.facture.montantht"
# The names are looked up in GET /api/database/<id>/metadata (hidden tables included) by
# PostgreSQL, in the container, like every JSON document read by these scripts.
#
# mb_db_id                        prints the id of pachadataformation
# mb_collection NAME              prints the id of the collection NAME at the root, made if missing
# mb_card_id NAME                 prints the id of the question NAME (not archived), or nothing
# mb_save_card TEMPLATE [COLL]    creates the question of TEMPLATE in the collection COLL (an
#                                 id; the root when empty), or replaces the question of the same
#                                 name; prints its id
# mb_save_dashboard TEMPLATE [COLL]  creates the dashboard of TEMPLATE in the collection COLL,
#                                 or empties and fills again the dashboard of the same name
#                                 there; prints its id. The template holds "name",
#                                 "parameters" (the filters, as PUT /api/dashboard takes them)
#                                 and "dashcards", where each card names its question
#                                 ("card": "Paiements par mode", null for a text card) and its
#                                 parameter_mappings leave out card_id; the questions must
#                                 exist, and "@..." names are replaced as for a question
# mb_run_card ID OUT              runs a saved question, writes the JSON answer to OUT
# mb_run_template TEMPLATE OUT    runs the query of a template without saving it
# mb_id REF                       prints the id of "@schema.table" or "@schema.table.field"
# mb_rows FILE                    prints the rows of an answer, one per line, columns
#                                 separated by " | ", after a line with the column names

# Its temporary folder is removed when the script ends.
mb_tmp=$(mktemp -d)
trap 'rm -rf "$mb_tmp"' EXIT

mb_db_id() {
    mb_call GET /api/database "$mb_tmp/databases.json" >/dev/null
    json_sql "$mb_tmp/databases.json" "
        select d->>'id'
          from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
         where d->'details'->>'dbname' = 'pachadataformation'
           and not coalesce((d->>'is_sample')::boolean, false)
         limit 1"
}

mb_collection() {
    local name=$1 id
    mb_call GET /api/collection "$mb_tmp/collections.json" >/dev/null
    id=$(json_sql "$mb_tmp/collections.json" "
        select c->>'id' from j, jsonb_array_elements(doc) c
         where c->>'name' = $(sql_text "$name") and c->>'location' = '/'
           and c->>'personal_owner_id' is null and not coalesce((c->>'archived')::boolean, false)
         order by (c->>'id')::int limit 1")
    if [ -z "$id" ]; then
        printf '{"name":%s,"parent_id":null}' "$(json_text "$name")" > "$mb_tmp/collection.json"
        mb_call POST /api/collection "$mb_tmp/collection-new.json" "$mb_tmp/collection.json" >/dev/null
        id=$(json_sql "$mb_tmp/collection-new.json" "select doc->>'id' from j")
    fi
    printf '%s\n' "$id"
}

mb_card_id() {
    mb_call GET /api/card "$mb_tmp/cards.json" >/dev/null
    json_sql "$mb_tmp/cards.json" "
        select c->>'id' from j, jsonb_array_elements(doc) c
         where c->>'name' = $(sql_text "$1") and not coalesce((c->>'archived')::boolean, false)
         order by (c->>'id')::int desc limit 1"
}

# mb_resolve TEMPLATE OUT: the template with its names replaced by ids.
mb_resolve() {
    local db
    db=$(mb_db_id)
    [ -n "$db" ] || { echo "pachadataformation is not connected in Metabase" >&2; return 1; }
    mb_call GET "/api/database/$db/metadata?include_hidden=true" "$mb_tmp/metadata.json" >/dev/null
    json_sql "$mb_tmp/metadata.json" "
        create function pg_temp.resolve(t text, db int) returns text language plpgsql as \$\$
        declare
            m text[];
            ref text;
            id int;
        begin
            t := replace(t, '\"@database\"', db::text);
            for m in select regexp_matches(t, '\"@([a-z0-9_]+)\\.([a-z0-9_]+)(\\.([a-z0-9_]+))?\"', 'g') loop
                ref := m[1] || '.' || m[2] || coalesce('.' || nullif(m[4], ''), '');
                if nullif(m[4], '') is null then
                    select (x->>'id')::int into id
                      from j, jsonb_array_elements(j.doc->'tables') x
                     where x->>'schema' = m[1] and x->>'name' = m[2];
                else
                    select (f->>'id')::int into id
                      from j, jsonb_array_elements(j.doc->'tables') x, jsonb_array_elements(x->'fields') f
                     where x->>'schema' = m[1] and x->>'name' = m[2] and f->>'name' = m[4];
                end if;
                if id is null then
                    raise exception 'not found in the metadata of Metabase: %', ref;
                end if;
                t := replace(t, '\"@' || ref || '\"', id::text);
            end loop;
            return t;
        end \$\$;
        select pg_temp.resolve($(sql_text "$(cat "$1")"), $db);" > "$2"
    [ -s "$2" ]
}

mb_save_card() {
    local template=$1 coll=${2:-} name id code
    mb_resolve "$template" "$mb_tmp/body.json" || return 1
    if [ -n "$coll" ]; then
        json_sql "$mb_tmp/body.json" "select jsonb_set(doc, '{collection_id}', to_jsonb($coll)) from j" > "$mb_tmp/body2.json"
    else
        json_sql "$mb_tmp/body.json" "select jsonb_set(doc, '{collection_id}', 'null') from j" > "$mb_tmp/body2.json"
    fi
    name=$(json_sql "$mb_tmp/body2.json" "select doc->>'name' from j")
    id=$(mb_card_id "$name")
    if [ -n "$id" ]; then
        code=$(mb_call PUT "/api/card/$id" "$mb_tmp/card.json" "$mb_tmp/body2.json")
    else
        code=$(mb_call POST /api/card "$mb_tmp/card.json" "$mb_tmp/body2.json")
    fi
    if [ "$code" != 200 ]; then
        echo "Metabase did not save \"$name\" (HTTP $code)" >&2
        return 1
    fi
    json_sql "$mb_tmp/card.json" "select doc->>'id' from j"
}

mb_save_dashboard() {
    local template=$1 coll=${2:-} name id code missing
    mb_resolve "$template" "$mb_tmp/dash-template.json" || return 1
    mb_call GET /api/card "$mb_tmp/cards.json" >/dev/null
    # One document for psql: the template and the saved questions, read together.
    { printf '{"t":'; cat "$mb_tmp/dash-template.json"; printf ',"cards":'; cat "$mb_tmp/cards.json"; printf '}'; } \
        > "$mb_tmp/dash-input.json"
    missing=$(json_sql "$mb_tmp/dash-input.json" "
        select string_agg(dc->>'card', ', ')
          from j, jsonb_array_elements(doc->'t'->'dashcards') dc
         where dc->>'card' is not null
           and not exists (select from jsonb_array_elements(doc->'cards') c
                            where c->>'name' = dc->>'card' and not coalesce((c->>'archived')::boolean, false))")
    if [ -n "$missing" ]; then
        echo "No question named $missing in Metabase" >&2
        return 1
    fi
    # The body of PUT /api/dashboard/<id>: new cards get negative ids, each question its id.
    json_sql "$mb_tmp/dash-input.json" "
        select jsonb_build_object('parameters', coalesce(doc->'t'->'parameters', '[]'), 'tabs', '[]'::jsonb,
                 'dashcards', (select jsonb_agg(jsonb_build_object(
                      'id', -n, 'card_id', c.id, 'row', dc->'row', 'col', dc->'col',
                      'size_x', dc->'size_x', 'size_y', dc->'size_y',
                      'visualization_settings', coalesce(dc->'visualization_settings', '{}'),
                      'parameter_mappings', coalesce((select jsonb_agg(m || jsonb_build_object('card_id', c.id))
                                                        from jsonb_array_elements(dc->'parameter_mappings') m), '[]'))
                      order by n)
                   from jsonb_array_elements(doc->'t'->'dashcards') with ordinality x(dc, n)
                   left join lateral (select max((cd->>'id')::int) as id from jsonb_array_elements(doc->'cards') cd
                                       where cd->>'name' = dc->>'card'
                                         and not coalesce((cd->>'archived')::boolean, false)) c on true))
          from j" > "$mb_tmp/dash-body.json"
    name=$(json_sql "$mb_tmp/dash-template.json" "select doc->>'name' from j")
    mb_call GET "/api/collection/${coll:-root}/items?models=dashboard" "$mb_tmp/items.json" >/dev/null
    id=$(json_sql "$mb_tmp/items.json" "
        select min((i->>'id')::int) from j, jsonb_array_elements(doc->'data') i
         where i->>'name' = $(sql_text "$name")")
    if [ -z "$id" ]; then
        printf '{"name":%s,"collection_id":%s}' "$(json_text "$name")" "${coll:-null}" > "$mb_tmp/dash-new.json"
        code=$(mb_call POST /api/dashboard "$mb_tmp/dash.json" "$mb_tmp/dash-new.json")
        if [ "$code" != 200 ]; then
            echo "Metabase did not create the dashboard \"$name\" (HTTP $code)" >&2
            return 1
        fi
        id=$(json_sql "$mb_tmp/dash.json" "select doc->>'id' from j")
    fi
    code=$(mb_call PUT "/api/dashboard/$id" "$mb_tmp/dash.json" "$mb_tmp/dash-body.json")
    if [ "$code" != 200 ]; then
        echo "Metabase did not save the cards of \"$name\" (HTTP $code)" >&2
        return 1
    fi
    printf '%s\n' "$id"
}

mb_run_card() {
    mb_call POST "/api/card/$1/query" "$2" >/dev/null
}

mb_rows() {
    json_sql "$1" "
        select string_agg(c->>'display_name', ' | ' order by i) from j, jsonb_array_elements(doc->'data'->'cols') with ordinality x(c, i)
        union all
        (select (select string_agg(coalesce(v, '(empty)'), ' | ' order by k)
                   from jsonb_array_elements_text(r) with ordinality y(v, k))
           from j, jsonb_array_elements(doc->'data'->'rows') with ordinality z(r, n)
          order by n)"
}

# mb_id REF: the id of "@schema.table" or "@schema.table.field".
mb_id() {
    printf '"@%s"' "$1" > "$mb_tmp/ref.json"
    mb_resolve "$mb_tmp/ref.json" "$mb_tmp/ref-id.json" && cat "$mb_tmp/ref-id.json"
}

# mb_run_template TEMPLATE OUT: runs the query of a template without saving it
# (POST /api/dataset), as the query builder does before the question is saved.
mb_run_template() {
    mb_resolve "$1" "$mb_tmp/run-body.json" || return 1
    json_sql "$mb_tmp/run-body.json" "select doc->'dataset_query' from j" > "$mb_tmp/run-query.json"
    mb_call POST /api/dataset "$2" "$mb_tmp/run-query.json" >/dev/null
}
