#!/usr/bin/env bash
# Copies the solution of exercise 11 to site/planning.sql, where SQLPage serves it. Used by the
# continuous integration before ./setup/check.sh 11; you can run it to see the solution at
# http://localhost:8080/planning.sql. A site/planning.sql of your own is kept, unless you pass
# --force.
# Usage: ./exercises/module_11/solution/create.sh [--force]
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
src=exercises/module_11/solution/planning.sql
dst=site/planning.sql
if [ -f "$dst" ] && ! cmp -s "$src" "$dst" && [ "${1:-}" != --force ]; then
    echo "$dst exists and is not the solution; it is kept. Run again with --force to replace it." >&2
    exit 1
fi
cp "$src" "$dst"
echo "Page $dst written (http://localhost:${SQLPAGEPORT:-8080}/planning.sql)."
