#!/usr/bin/env bash
# Creates the question "Exercice 02" of the solution in Metabase, at the root collection, or
# replaces the question of that name: the definition the query builder makes, written in
# exercice-02.json with names in place of ids (see setup/mbql.sh). Used by the continuous
# integration before ./setup/check.sh 02; you can run it to see the solution in Metabase.
# Usage: ./exercises/module_02/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
. setup/mbql.sh
id=$(mb_save_card exercises/module_02/solution/exercice-02.json)
echo "Question \"Exercice 02\" saved (id $id)."
