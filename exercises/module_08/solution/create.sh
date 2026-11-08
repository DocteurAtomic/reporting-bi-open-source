#!/usr/bin/env bash
# Creates the materialized view entrepot.visites_par_stage (matview.sql, run as postgres in
# the db container), asks Metabase to sync the schema and waits for the view, then creates the
# question "Exercice 08" that reads it (exercice-08.json, names in place of ids, see
# setup/mbql.sh), at the root collection, or replaces it. Needs ./setup/volume.sh. Used by the
# continuous integration before ./setup/check.sh 08; you can run it to see the solution.
# Usage: ./exercises/module_08/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
. setup/mbql.sh
d=exercises/module_08/solution
psql_lab -d pachadataformation -q -v ON_ERROR_STOP=1 < "$d/matview.sql"
echo "Materialized view entrepot.visites_par_stage created."
mb_sync entrepot.visites_par_stage
id=$(mb_save_card "$d/exercice-08.json")
echo "Question \"Exercice 08\" saved (id $id)."
