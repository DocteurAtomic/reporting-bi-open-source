#!/usr/bin/env bash
# Clip 5.3. Arranges "Tableau de bord de la facturation" on two tabs and sets what a click does:
# - tab "Activité": the text card, "Chiffre d'affaires par stage", "Paiements par mode",
#   "Encaissements par période"; tab "Impayés": "Factures sans paiement par année".
#   "Encaissements par mois", which the filter cannot reach, leaves the dashboard (end of
#   clip 5.2). The filter "Période" keeps its connections.
# - a click on a course in "Chiffre d'affaires par stage" opens the SQL question "Factures d'un
#   stage" (03-invoices-of-a-course.json, made or replaced) with the clicked course in
#   {{stage}} and the value of the filter "Période" in {{periode}};
# - a click on a bar of "Factures sans paiement par année" keeps the drill-through menu of
#   Metabase, whose "See these Factures" lists the invoices of the bar: nothing to set.
# Then runs "Factures d'un stage" as the click would, for one course and the year 2011.
# Usage: ./demos/module_05/03-tabs.sh ["SQL Server 2005 Expertise" [2011-01-01~2011-12-31]]
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_05
name="Tableau de bord de la facturation"
course=${1:-SQL Server 2005 Expertise}
value=${2:-2011-01-01~2011-12-31}

mb_call GET /api/dashboard "$mb_tmp/dashboards.json" >/dev/null
dash=$(json_sql "$mb_tmp/dashboards.json" "
    select max((d->>'id')::int) from j, jsonb_array_elements(doc) d
     where d->>'name' = $(sql_text "$name") and not coalesce((d->>'archived')::boolean, false)")
[ -n "$dash" ] || { echo "No dashboard named \"$name\": run 01-dashboard.sh first." >&2; exit 1; }
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null
coll=$(json_sql "$mb_tmp/dash.json" "select doc->>'collection_id' from j")
target=$(mb_save_card "$d/03-invoices-of-a-course.json" "$coll")

# Two tabs (new tabs get negative ids), each card on its tab, the click on a course.
json_sql "$mb_tmp/dash.json" "
    create function pg_temp.place(dc jsonb, tab int, r int, c int, w int, h int) returns jsonb language sql as
      \$\$ select jsonb_build_object('id', dc->'id', 'card_id', dc->'card_id', 'dashboard_tab_id', tab,
                                    'row', r, 'col', c, 'size_x', w, 'size_y', h,
                                    'parameter_mappings', dc->'parameter_mappings',
                                    'visualization_settings', dc->'visualization_settings') \$\$;
    select jsonb_build_object(
      'parameters', doc->'parameters',
      'tabs', '[{\"id\": -1, \"name\": \"Activité\"}, {\"id\": -2, \"name\": \"Impayés\"}]'::jsonb,
      'dashcards', (select jsonb_agg(x) from (
          select case coalesce(dc->'card'->>'name', '')
                   when '' then pg_temp.place(dc, -1, 0, 0, 24, 3)
                   when 'Chiffre d''affaires par stage' then jsonb_set(pg_temp.place(dc, -1, 3, 0, 12, 7),
                       '{visualization_settings,column_settings}', jsonb_build_object('[\"name\",\"titre\"]',
                         jsonb_build_object('click_behavior', jsonb_build_object(
                           'type', 'link', 'linkType', 'question', 'targetId', $target,
                           'parameterMapping', jsonb_build_object(
                             'f05a0010', jsonb_build_object('id', 'f05a0010',
                                 'source', jsonb_build_object('type', 'column', 'id', 'titre', 'name', 'Stagelangue → Titre'),
                                 'target', jsonb_build_object('type', 'variable', 'id', 'stage')),
                             'f05a0011', jsonb_build_object('id', 'f05a0011',
                                 'source', jsonb_build_object('type', 'parameter', 'id', 'f05a0001', 'name', 'Période'),
                                 'target', jsonb_build_object('type', 'variable', 'id', 'periode')))))))
                   when 'Paiements par mode' then pg_temp.place(dc, -1, 3, 12, 12, 3)
                   when 'Encaissements par période' then pg_temp.place(dc, -1, 6, 12, 12, 7)
                   when 'Factures sans paiement par année' then pg_temp.place(dc, -2, 0, 0, 24, 8)
                 end as x
            from jsonb_array_elements(doc->'dashcards') dc) p
         where x is not null))
      from j" > "$mb_tmp/body.json"
code=$(mb_call PUT "/api/dashboard/$dash" "$mb_tmp/dash.json" "$mb_tmp/body.json")
[ "$code" = 200 ] || { echo "Metabase did not save the tabs (HTTP $code): $(head -c 300 "$mb_tmp/dash.json")" >&2; exit 1; }
echo "\"$name\" (id $dash):"
json_sql "$mb_tmp/dash.json" "
    select format('  tab %s, dashcard %s: %s%s', t->>'name', dc->>'id', coalesce(dc->'card'->>'name', '(text card)'),
                  case when dc->'visualization_settings'->'column_settings' is not null
                       then ' (click on a course: \"Factures d''un stage\")' else '' end)
      from j, jsonb_array_elements(doc->'dashcards') dc
      join jsonb_array_elements(doc->'tabs') t on t->'id' = dc->'dashboard_tab_id'
     order by (t->>'position')::int, (dc->>'row')::int, (dc->>'col')::int"

# "Factures d'un stage", run as the click on the course would run it.
printf '{"parameters":[{"id":"f05a0010","type":"string/=","target":["dimension",["template-tag","stage"]],"value":[%s]},{"id":"f05a0011","type":"date/all-options","target":["dimension",["template-tag","periode"]],"value":%s}]}' \
    "$(json_text "$course")" "$(json_text "$value")" > "$mb_tmp/values.json"
mb_call POST "/api/card/$target/query" "$mb_tmp/answer.json" "$mb_tmp/values.json" >/dev/null
echo "-- \"Factures d'un stage\" (id $target), stage = $course, période = $value:"
json_sql "$mb_tmp/answer.json" "
    select format('%s invoices, %s before tax', jsonb_array_length(doc->'data'->'rows'),
                  (select sum((r->>2)::numeric) from jsonb_array_elements(doc->'data'->'rows') r))
      from j"
