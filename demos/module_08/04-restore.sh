#!/usr/bin/env bash
# Clip 8.4. Restores a backup of 04-backup.sh into the lab of this clone: stops Metabase,
# replaces its application database metabase by the dump, starts Metabase again and waits for
# /api/health. Everything Metabase held is replaced by what the dump holds.
# Meant for a new lab: a new clone, the .env of the old lab copied into it before
# ./setup/install.sh (so that lecture_bi, metabase and the API key keep the passwords the dump
# knows), then this script. Metabase, at its start, applies the migrations its version needs to
# the restored database: that is also how an upgrade goes (a new image tag in compose.yaml,
# then docker compose up -d).
# Usage: ./demos/module_08/04-restore.sh work/metabase-YYYYMMDD-HHMMSS.dump
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
dump=${1:-}
[ -f "$dump" ] || { echo "usage: $0 work/metabase-YYYYMMDD-HHMMSS.dump" >&2; exit 1; }
lab_running "$c" || { echo "The container $c (PostgreSQL) is not running: start the lab with ./setup/install.sh." >&2; exit 1; }

echo "Stopping Metabase..."
$compose stop metabase >/dev/null
psql_lab -d postgres -q -v ON_ERROR_STOP=1 <<'SQL'
drop database if exists metabase with (force);
create database metabase owner metabase;
revoke connect on database metabase from public;
SQL
start=$SECONDS
$engine exec -i "$c" pg_restore -U postgres -d metabase --no-owner --role=metabase --exit-on-error < "$dump"
echo "Restored in $((SECONDS - start)) s. Starting Metabase..."
$compose up -d metabase >/dev/null
start=$SECONDS
until mb_healthy; do
    [ $((SECONDS - start)) -lt 180 ] || { echo "Metabase does not answer after 3 minutes: $compose logs metabase" >&2; exit 1; }
    sleep 2
done
echo "Metabase answers on $mb_url after $((SECONDS - start)) s."
psql_lab -d metabase -At -c "select 'questions, models and metrics: ' || count(*) filter (where not archived) from report_card" \
                       -c "select 'dashboards: ' || count(*) filter (where not archived) from report_dashboard" \
                       -c "select 'migrations applied (databasechangelog): ' || count(*) from databasechangelog"
