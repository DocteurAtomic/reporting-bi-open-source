#!/usr/bin/env bash
# Saves a question in Metabase from a JSON file, through the API, with the API key of .env:
# creates it, or replaces the question of the same name. The solutions of the exercises use
# it, and the continuous integration recreates their questions with it before
# ./setup/check.sh. The file is the body of POST /api/card, with names in place of the ids
# that differ from one lab to another ("@database", "@schema.table", "@schema.table.column"):
# see setup/mbql.sh, which does the work.
# Usage: ./setup/create-card.sh FILE.json [COLLECTION_ID]
# Prints the id of the question. Exit codes: 0 saved; 1 the lab has a problem, a name of the
# file is unknown, or Metabase refuses the question.
set -uo pipefail
[ $# -ge 1 ] && [ -f "$1" ] || { echo "usage: $0 FILE.json [COLLECTION_ID]" >&2; exit 1; }
file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$0")/.."
. setup/lib.sh
. setup/mbql.sh
mb_save_card "$file" "${2:-}"
