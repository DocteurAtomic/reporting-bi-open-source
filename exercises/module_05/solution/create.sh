#!/usr/bin/env bash
# Creates the dashboard "Exercice 05" of the solution in Metabase, or empties and fills again
# the dashboard of that name, as the continuous integration does before it runs
# ./setup/check.sh 05: the three questions of the planning (made or replaced), then the
# dashboard with its filter "Année" connected to the three of them. Everything goes in the
# collection "Planning", made if missing. The definitions are the JSON files of this folder,
# with names in place of ids (see setup/mbql.sh).
# Usage: ./exercises/module_05/solution/create.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../../setup/lib.sh"
. setup/mbql.sh
coll=$(mb_collection "${COLLECTION:-Planning}")
for q in sessions-par-annee moyenne-par-session stages-les-plus-programmes; do
    mb_save_card "$here/$q.json" "$coll" >/dev/null
done
mb_save_dashboard "$here/exercice-05.json" "$coll"
