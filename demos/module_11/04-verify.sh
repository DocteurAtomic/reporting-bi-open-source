#!/usr/bin/env bash
# Video 11.4: checks the page written by hand (site/facturation.sql) and the page written by
# Claude Code (site/facturation-claude.sql) against the same references,
# demos/module_11/02-references.sql, with setup/verify-page.sh. Run it before and after the
# review of the agent's page: both runs must pass. Exit code: the worse of the two.
set -uo pipefail
cd "$(dirname "$0")/../.."
worst=0
for page in facturation.sql facturation-claude.sql; do
    echo "== $page"
    setup/verify-page.sh demos/module_11/02-references.sql "$page"
    code=$?
    [ "$code" -gt "$worst" ] && worst=$code
done
exit "$worst"
