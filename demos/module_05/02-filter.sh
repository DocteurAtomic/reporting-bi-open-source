#!/usr/bin/env bash
# Clip 5.2. Adds the filter "Période" (date, all options) to "Tableau de bord de la facturation"
# and connects it to the cards that have a date to filter:
#   "Factures sans paiement par année"   the column Datefacture of Facture
#   "Chiffre d'affaires par stage"       the column Datefacture of Facture (first stage)
#   "Paiements par mode"                 the column Datepaiement of Suivifacture
#   "Encaissements par période"          its field filter {{periode}}
# "Encaissements par mois" stays unconnected: its variable {{annee}} is a number, and a date
# filter can only reach a field filter or a column (clip 5.2 shows what that does).
# Then runs every card through the dashboard, as the browser does, with the value given
# (2011 when none), and prints the first rows of each.
# Usage: ./demos/module_05/02-filter.sh [2011-01-01~2011-12-31]
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
name="Tableau de bord de la facturation"
value=${1:-2011-01-01~2011-12-31}
param=f05a0001

mb_call GET /api/dashboard "$mb_tmp/dashboards.json" >/dev/null
dash=$(json_sql "$mb_tmp/dashboards.json" "
    select max((d->>'id')::int) from j, jsonb_array_elements(doc) d
     where d->>'name' = $(sql_text "$name") and not coalesce((d->>'archived')::boolean, false)")
[ -n "$dash" ] || { echo "No dashboard named \"$name\": run 01-dashboard.sh first." >&2; exit 1; }
datefacture=$(mb_id inscription.facture.datefacture)
datepaiement=$(mb_id inscription.suivifacture.datepaiement)
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null

# The body of PUT /api/dashboard/<id>: the filter, and each card with its connection.
json_sql "$mb_tmp/dash.json" "
    create function pg_temp.mapping(card jsonb, target jsonb) returns jsonb language sql as
      \$\$ select jsonb_build_array(jsonb_build_object('parameter_id', '$param', 'card_id', card, 'target', target)) \$\$;
    create function pg_temp.on_field(id int) returns jsonb language sql as
      \$\$ select jsonb_build_array('dimension', jsonb_build_array('field', id, '{\"base-type\": \"type/Date\"}'::jsonb),
                                   '{\"stage-number\": 0}'::jsonb) \$\$;
    select jsonb_build_object(
      'parameters', jsonb_build_array(jsonb_build_object('id', '$param', 'name', 'Période',
                      'slug', 'periode', 'type', 'date/all-options', 'sectionId', 'date')),
      'tabs', coalesce(doc->'tabs', '[]'),
      'dashcards', (select jsonb_agg(
          jsonb_build_object('id', dc->'id', 'card_id', dc->'card_id', 'dashboard_tab_id', dc->'dashboard_tab_id',
                             'row', dc->'row', 'col', dc->'col', 'size_x', dc->'size_x', 'size_y', dc->'size_y',
                             'visualization_settings', dc->'visualization_settings',
                             'parameter_mappings', case dc->'card'->>'name'
              when 'Factures sans paiement par année' then pg_temp.mapping(dc->'card_id', pg_temp.on_field($datefacture))
              when 'Chiffre d''affaires par stage' then pg_temp.mapping(dc->'card_id', pg_temp.on_field($datefacture))
              when 'Paiements par mode' then pg_temp.mapping(dc->'card_id', pg_temp.on_field($datepaiement))
              when 'Encaissements par période' then pg_temp.mapping(dc->'card_id',
                  '[\"dimension\", [\"template-tag\", \"periode\"], {\"stage-number\": 0}]'::jsonb)
              else '[]'::jsonb end))
        from jsonb_array_elements(doc->'dashcards') dc))
      from j" > "$mb_tmp/body.json"
code=$(mb_call PUT "/api/dashboard/$dash" "$mb_tmp/dash.json" "$mb_tmp/body.json")
[ "$code" = 200 ] || { echo "Metabase did not save the filter (HTTP $code): $(head -c 300 "$mb_tmp/dash.json")" >&2; exit 1; }

# Every card, run through the dashboard with the value of the filter.
printf '{"parameters":[{"id":"%s","type":"date/all-options","value":%s}]}' "$param" "$(json_text "$value")" > "$mb_tmp/value.json"
echo "\"$name\" (id $dash), filter Période = $value:"
json_sql "$mb_tmp/dash.json" "
    select concat_ws(' ', dc->>'id', dc->>'card_id', jsonb_array_length(dc->'parameter_mappings'), dc->'card'->>'name')
      from j, jsonb_array_elements(doc->'dashcards') dc
     where dc->>'card_id' is not null
     order by (dc->>'row')::int, (dc->>'col')::int" > "$mb_tmp/cards.txt"
while read -r dc cid mapped card_name; do
    mb_call POST "/api/dashboard/$dash/dashcard/$dc/card/$cid/query" "$mb_tmp/answer.json" "$mb_tmp/value.json" >/dev/null
    if [ "$mapped" = 0 ]; then state="not connected"; else state="connected"; fi
    json_sql "$mb_tmp/answer.json" "
        select format('-- %s (%s): %s rows', $(sql_text "$card_name"), $(sql_text "$state"),
                      coalesce(jsonb_array_length(doc->'data'->'rows')::text, 'error ' || coalesce(doc->>'error', '')))
          from j"
    json_sql "$mb_tmp/answer.json" "
        select (select string_agg(coalesce(v, '(empty)'), ' | ' order by k) from jsonb_array_elements_text(r) with ordinality y(v, k))
          from j, jsonb_array_elements(doc->'data'->'rows') with ordinality z(r, n)
         where n <= 3 order by n"
done < "$mb_tmp/cards.txt"
