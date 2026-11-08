#!/usr/bin/env bash
# Clip 5.4. Verifies "Tableau de bord de la facturation" card by card with
# setup/verify-dashboard.sh: each card run through the dashboard with the value of the filter
# "Période" (2011 when none is given), and compared with its query in 04-references.sql.
# Usage: ./demos/module_05/04-verify.sh [2011-01-01~2011-12-31]
cd "$(dirname "$0")/../.." || exit 1
exec ./setup/verify-dashboard.sh "Tableau de bord de la facturation" demos/module_05/04-references.sql "${1:-2011-01-01~2011-12-31}"
