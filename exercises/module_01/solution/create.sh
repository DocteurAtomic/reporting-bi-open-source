#!/usr/bin/env bash
# Creates the solution of exercise 01 in Metabase, through the API: the question "Exercice 01",
# the count of contacts by title (contact.contact.titre), the contacts without a title included.
# The continuous integration runs it before ./setup/check.sh 01. Delete the question in Metabase
# before you build your own, or check.sh reads the most recently changed one.
# Usage, from the root of the clone: ./exercises/module_01/solution/create.sh
exec "$(dirname "$0")/../../../setup/create-card.sh" "$(dirname "$0")/exercice-01.json"
