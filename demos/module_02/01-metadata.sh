#!/usr/bin/env bash
# Clip 2.1. The metadata changes of the clip, made through the API, as Administration > Table
# Metadata makes them in the browser. The sync reads the primary keys (lecture_bi has the
# privilege references), but not the two-column key of stage.session to stage.stagelangue:
# it reads it as two foreign keys to stagelangue.languecd. And the database declares no key
# from inscription.inscription.sessionid to stage.session. So:
# - the two tables of the schema outils (nombre, tallydate) are hidden;
# - stage.stagelangue.stageid becomes an entity key (one language per stage in this database,
#   so one row per stageid), and stage.session.stageid a foreign key to it;
# - stage.session.languecd becomes a foreign key to stage.langue.languecd, the table of the
#   languages, instead of stagelangue.languecd, which matches every stage of the language;
# - inscription.inscription.sessionid becomes a foreign key to stage.session.sessionid;
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
echo "stage.stagelangue.stageid: entity key"

put "/api/field/$(mb_id stage.session.stageid)" \
    "{\"semantic_type\":\"type/FK\",\"fk_target_field_id\":$stagelangue_id}"
echo "stage.session.stageid: foreign key to stage.stagelangue.stageid"

put "/api/field/$(mb_id stage.session.languecd)" \
    "{\"semantic_type\":\"type/FK\",\"fk_target_field_id\":$(mb_id stage.langue.languecd)}"
echo "stage.session.languecd: foreign key to stage.langue.languecd"

put "/api/field/$(mb_id inscription.inscription.sessionid)" \
    "{\"semantic_type\":\"type/FK\",\"fk_target_field_id\":$(mb_id stage.session.sessionid)}"
echo "inscription.inscription.sessionid: foreign key to stage.session.sessionid"

put "/api/field/$(mb_id inscription.facture.montantht)" '{"display_name":"Montant HT"}'
echo "inscription.facture.montantht: shown as Montant HT"
