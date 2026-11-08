#!/usr/bin/env bash
# Creates the question "Exercice 10" of the solution in Metabase, at the root collection, or
# replaces the question of that name: the question Claude Code built through the MCP server on
# the lab of the course (8 November 2026), written again in exercice-10.json in the form of the
# query builder, with names in place of ids (see setup/mbql.sh). Used by the continuous
# integration before ./setup/check.sh 10, which cannot run Claude Code; you can run it to see
# the solution in Metabase.
# Usage: ./exercises/module_10/solution/create.sh
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
. setup/mbql.sh
id=$(mb_save_card exercises/module_10/solution/exercice-10.json)
echo "Question \"Exercice 10\" saved (id $id)."
