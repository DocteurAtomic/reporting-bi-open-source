#!/usr/bin/env bash
# Videos 11.1 and 11.2: asks SQLPage for a page in JSON (Accept: application/json), the form
# setup/verify-page.sh reads: one object per component, then one object per row.
# Usage: ./demos/module_11/01-json.sh [PAGE]   (index.sql by default)
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
page=${1:-index.sql}
curl -sS -H 'Accept: application/json' "http://127.0.0.1:${SQLPAGEPORT:-8080}/${page#site/}"
echo
