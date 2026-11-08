#!/usr/bin/env bash
# Copies the solution of exercise 9 to work/answer09.csv, where ./setup/check.sh 09 reads it.
# Used by the continuous integration, which asks no question to Metabot: the file holds the
# verdicts written after the answers of Metabot of 8 November 2026 (metabot-2026-11-08.txt).
# A work/answer09.csv of your own is kept, unless you pass --force.
# Usage: ./exercises/module_09/solution/create.sh [--force]
set -euo pipefail
. "$(dirname "$0")/../../../setup/lib.sh"
src=exercises/module_09/solution/answer09.csv
dst=work/answer09.csv
if [ -f "$dst" ] && ! cmp -s "$src" "$dst" && [ "${1:-}" != --force ]; then
    echo "$dst exists and is not the solution; it is kept. Run again with --force to replace it." >&2
    exit 1
fi
cp "$src" "$dst"
echo "File $dst written."
