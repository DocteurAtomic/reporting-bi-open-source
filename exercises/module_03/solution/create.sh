#!/usr/bin/env bash
# Creates the question "Exercice 03" of the solution in Metabase, or replaces the question of
# that name, as the continuous integration does before it runs ./setup/check.sh 03. The
# definition is exercice-03.json (the same question as exercice-03.sql, typed in the SQL
# editor), with names in place of ids (see setup/mbql.sh).
# Usage: ./exercises/module_03/solution/create.sh
set -euo pipefail
exec "$(dirname "$0")/../../../setup/create-card.sh" "$(dirname "$0")/exercice-03.json"
