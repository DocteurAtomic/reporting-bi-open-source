#!/usr/bin/env bash
# Creates in Metabase, through the API, the five questions that module 3 builds by hand:
#   "Chiffre d'affaires par stage en SQL"   01-revenue-by-course.sql, no variable (clip 3.1)
#   "Encaissements par mois"                02-payments-by-month.sql, number variable {{annee}},
#                                           default 2011 (clip 3.2)
#   "Encaissements par période"             03-payments-by-period.sql, field filter {{periode}}
#                                           on Suivifacture > Datepaiement (clip 3.3)
#   "Total du chiffre d'affaires par stage" and "Encaissements depuis la période", two
#                                           questions of the editor built on the two saved SQL
#                                           questions above (clip 3.4)
# They go in the collection "Facturation" when it exists (module 2), in "Nos analyses"
# otherwise. A question whose name is already used is left as it is. For a lab that skipped
# the clips, and for the continuous integration; the clips build the same questions by hand.
# Usage, from the root of the clone: ./demos/module_03/create-questions.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { echo "$*" >&2; exit 1; }

# The SQL of a file of this folder as a JSON string: comment lines and the final semicolon
# dropped, so that the saved question holds the query alone.
sql_json() {
    local v
    v=$(grep -v '^--' "$here/$1" | sed 's/;[[:space:]]*$//')
    v=${v//\\/\\\\}; v=${v//\"/\\\"}; v=${v//$'\n'/\\n}
    printf '"%s"' "$v"
}

code=$(mb_call GET /api/database "$tmp/databases.json")
[ "$code" = 200 ] || fail "Metabase refuses the API key of .env (HTTP $code)"
db=$(json_sql "$tmp/databases.json" "
    select d->>'id'
      from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
     where d->'details'->>'dbname' = 'pachadataformation' and d->>'engine' = 'postgres'")
[ -n "$db" ] || fail "pachadataformation is not connected in Metabase"

mb_call GET "/api/database/$db/fields" "$tmp/fields.json" >/dev/null
field=$(json_sql "$tmp/fields.json" "
    select f->>'id' from j, jsonb_array_elements(doc) f
     where f->>'schema' = 'inscription' and f->>'table_name' = 'suivifacture' and f->>'name' = 'datepaiement'")
[ -n "$field" ] || fail "Metabase does not know inscription.suivifacture.datepaiement (sync the database)"

mb_call GET /api/collection "$tmp/collections.json" >/dev/null
coll=$(json_sql "$tmp/collections.json" "
    select coalesce(min((c->>'id')::int)::text, 'null')
      from j, jsonb_array_elements(doc) c
     where c->>'name' = 'Facturation' and not coalesce((c->>'archived')::boolean, false)")

mb_call GET /api/card "$tmp/cards.json" >/dev/null

# card_id NAME: the id of the saved question of that name, empty when there is none.
card_id() {
    json_sql "$tmp/cards.json" "
        select min((c->>'id')::int) from j, jsonb_array_elements(doc) c
         where c->>'name' = $(sql_text "$1") and not coalesce((c->>'archived')::boolean, false)"
}

# create NAME BODY: creates the question unless its name is taken; prints its id.
create() {
    local id
    id=$(card_id "$1")
    if [ -n "$id" ]; then
        echo "\"$1\" already exists (id $id), left as it is." >&2
    else
        printf '%s\n' "$2" > "$tmp/body.json"
        code=$(mb_call POST /api/card "$tmp/created.json" "$tmp/body.json")
        [ "$code" = 200 ] || fail "Metabase refused \"$1\" (HTTP $code): $(cat "$tmp/created.json")"
        id=$(json_sql "$tmp/created.json" "select doc->>'id' from j")
        echo "\"$1\" created (id $id)." >&2
    fi
    printf '%s' "$id"
}

native() {  # native NAME SQL_FILE TEMPLATE_TAGS PARAMETERS
    create "$1" "{\"name\":$(json_text "$1"),\"display\":\"table\",\"visualization_settings\":{},\"collection_id\":$coll,\"parameters\":$4,\"dataset_query\":{\"database\":$db,\"type\":\"native\",\"native\":{\"query\":$(sql_json "$2"),\"template-tags\":$3}}}"
}
derived() {  # derived NAME SOURCE_ID AGGREGATIONS
    create "$1" "{\"name\":$(json_text "$1"),\"display\":\"table\",\"visualization_settings\":{},\"collection_id\":$coll,\"dataset_query\":{\"database\":$db,\"type\":\"query\",\"query\":{\"source-table\":\"card__$2\",\"aggregation\":$3}}}"
}

annee=0b6c4f1e-0303-4a10-8a3e-000000000001
periode=0b6c4f1e-0303-4a10-8a3e-000000000002
revenue=$(native "Chiffre d'affaires par stage en SQL" 01-revenue-by-course.sql '{}' '[]')
native "Encaissements par mois" 02-payments-by-month.sql \
    "{\"annee\":{\"id\":\"$annee\",\"name\":\"annee\",\"display-name\":\"Année\",\"type\":\"number\",\"default\":\"2011\",\"required\":true}}" \
    "[{\"id\":\"$annee\",\"type\":\"number/=\",\"target\":[\"variable\",[\"template-tag\",\"annee\"]],\"name\":\"Année\",\"slug\":\"annee\",\"default\":\"2011\",\"required\":true}]" >/dev/null
period=$(native "Encaissements par période" 03-payments-by-period.sql \
    "{\"periode\":{\"id\":\"$periode\",\"name\":\"periode\",\"display-name\":\"Période\",\"type\":\"dimension\",\"dimension\":[\"field\",$field,null],\"widget-type\":\"date/all-options\"}}" \
    "[{\"id\":\"$periode\",\"type\":\"date/all-options\",\"target\":[\"dimension\",[\"template-tag\",\"periode\"]],\"name\":\"Période\",\"slug\":\"periode\"}]")
derived "Total du chiffre d'affaires par stage" "$revenue" \
    '[["sum",["field","factures",{"base-type":"type/BigInteger"}]],["sum",["field","montant_ht",{"base-type":"type/Decimal"}]]]' >/dev/null
derived "Encaissements depuis la période" "$period" \
    '[["sum",["field","encaisse",{"base-type":"type/Decimal"}]],["count"]]' >/dev/null
