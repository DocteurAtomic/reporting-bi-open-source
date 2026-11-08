#!/usr/bin/env bash
# Creates the question "Exercice 04" of the solution in Metabase, at the root collection, or
# replaces the question of that name: the invoices by year from 2005 to 2011, in a line chart
# whose missing values are replaced by zero (series_settings, the setting the chart editor
# writes when you choose "Replace missing values with: Zero"). Written in exercice-04.json with
# names in place of ids (see setup/mbql.sh). Used by the continuous integration before
# ./setup/check.sh 04; you can run it to see the solution in Metabase.
# Usage: ./exercises/module_04/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
. setup/mbql.sh
id=$(mb_save_card exercises/module_04/solution/exercice-04.json)
echo "Question \"Exercice 04\" saved (id $id)."
