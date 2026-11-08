#!/usr/bin/env bash
# Creates the metric "Encaissements" (the sum of suivifacture.montant) and the question
# "Exercice 06" that uses it on the payments of 2011, at the root collection, or replaces them
# when they exist. Written in metric-encaissements.json and exercice-06.json with names in
# place of ids (see setup/mbql.sh). Used by the continuous integration before
# ./setup/check.sh 06; you can run it to see the solution in Metabase.
# Usage: ./exercises/module_06/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
. setup/mbql.sh
d=exercises/module_06/solution
metric=$(mb_save_card "$d/metric-encaissements.json")
echo "Metric \"Encaissements\" saved (id $metric)."
id=$(mb_save_card "$d/exercice-06.json")
echo "Question \"Exercice 06\" saved (id $id)."
