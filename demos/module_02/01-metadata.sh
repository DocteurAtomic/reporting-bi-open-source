#!/usr/bin/env bash
# Clip 2.1. The metadata changes of the clip, made through the API, as Administration > Table
# Metadata makes them in the browser:
# - the two tables of the schema outils (nombre, tallydate) are hidden;
# - stage.stagelangue.stageid and stage.session.sessionid become entity keys (Metabase
#   found no primary key under lecture_bi), and inscription.inscription.sessionid a foreign
#   key to session.sessionid (the database declares none);
# - stage.session.stageid, that the sync read from the two-column key of stage.stagelangue
#   as a foreign key to stagelangue.languecd (text), now points to stagelangue.stageid;
# - inscription.facture.montantht is shown as "Montant HT".
# It changes the metadata of Metabase only, never the database. It can be run again.
# Usage: ./demos/module_02/01-metadata.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh

put() { # put PATH JSON
    printf '%s' "$2" > "$mb_tmp/put.json"
    local code
    code=$(mb_call PUT "$1" "$mb_tmp/put-out.json" "$mb_tmp/put.json")
    [ "$code" = 200 ] || { echo "PUT $1 refused (HTTP $code)" >&2; exit 1; }
}

for t in outils.nombre outils.tallydate; do
    put "/api/table/$(mb_id "$t")" '{"visibility_type":"hidden"}'
    echo "table $t hidden"
done

stagelangue_id=$(mb_id stage.stagelangue.stageid)
put "/api/field/$stagelangue_id" '{"semantic_type":"type/PK"}'
echo "stage.stagelangue.stageid: entity key (one language per stage, so one row per stageid)"

session_id=$(mb_id stage.session.sessionid)
put "/api/field/$session_id" '{"semantic_type":"type/PK"}'
echo "stage.session.sessionid: entity key"

put "/api/field/$(mb_id inscription.inscription.sessionid)" \
    "{\"semantic_type\":\"type/FK\",\"fk_target_field_id\":$session_id}"
echo "inscription.inscription.sessionid: foreign key to stage.session.sessionid"

put "/api/field/$(mb_id stage.session.stageid)" \
    "{\"semantic_type\":\"type/FK\",\"fk_target_field_id\":$stagelangue_id}"
echo "stage.session.stageid: foreign key to stage.stagelangue.stageid"

put "/api/field/$(mb_id inscription.facture.montantht)" '{"display_name":"Montant HT"}'
echo "inscription.facture.montantht: shown as Montant HT"
