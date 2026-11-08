#!/usr/bin/env bash
# Clip 8.4. Backs up Metabase: everything built in it (questions, models, metrics, dashboards,
# collections, users, API keys, settings, cached answers) lives in its application database,
# the database metabase of the db container. pg_dump runs in the container and writes, in its
# custom format, to work/metabase-YYYYMMDD-HHMMSS.dump on your machine (work/ is ignored by
# git). The data of pachadataformation is not in it: the dump of the course gives it again.
# Keep the dump as you keep .env: Metabase stores the connection of pachadataformation in it,
# password of lecture_bi included, in clear unless MB_ENCRYPTION_SECRET_KEY is set.
# Usage: ./demos/module_08/04-backup.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
lab_running "$c" || { echo "The container $c (PostgreSQL) is not running: start the lab with ./setup/install.sh." >&2; exit 1; }

file=work/metabase-$(date +%Y%m%d-%H%M%S).dump
$engine exec "$c" pg_dump -U postgres -Fc -d metabase > "$file"
chmod 600 "$file"
echo "Application database of Metabase saved to $file ($(du -h "$file" | cut -f1))."
# What the dump holds, read back by pg_restore --list.
$engine exec -i "$c" pg_restore --list < "$file" | awk '$4 == "TABLE" && $5 != "DATA" { n++ } END { print n " tables in the dump" }'
psql_lab -d metabase -At -c "select 'questions, models and metrics: ' || count(*) filter (where not archived) from report_card" \
                       -c "select 'dashboards: ' || count(*) filter (where not archived) from report_dashboard" \
                       -c "select 'migrations applied (databasechangelog): ' || count(*) from databasechangelog"
