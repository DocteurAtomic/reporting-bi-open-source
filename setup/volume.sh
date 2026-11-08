#!/usr/bin/env bash
# Module 8. Creates the schema entrepot of pachadataformation and its fact table
# entrepot.visite (5 000 000 visits of the online catalogue, made up with a fixed seed by
# setup/volume.sql), then prints what it holds: the rows, the visits by year, the total time on
# the pages, and its size on disk. These totals are the ones to find again in Metabase.
# It takes a few seconds. The table takes 223 MB on disk, and the write-ahead log of
# PostgreSQL grows by about 450 MB, which PostgreSQL keeps for later writes: on a new lab the
# volume of the db service goes from about 400 MB to about 1.1 GB (measured on 8 November 2026).
# Usage: ./setup/volume.sh [--force | --drop]
#   When the table already exists, it only prints the totals; --force drops the schema entrepot
#   (the materialized views you made in it included) and creates it again; --drop drops the
#   schema entrepot and everything in it, to give the space of the table back.
# Then, in Metabase: Admin > Databases > pachadataformation > Sync database schema now, so that
# Metabase sees the new schema.
# Exit codes: 0 done; 1 the lab has a problem or PostgreSQL refused the script.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
mode=${1:-}
case "$mode" in ''|--force|--drop) ;; *) echo "usage: $0 [--force | --drop]" >&2; exit 1;; esac
lab_running "$c" || { echo "The container $c (PostgreSQL) is not running: start the lab with ./setup/install.sh." >&2; exit 1; }

exists=$(psql_lab -d pachadataformation -At -c "select to_regclass('entrepot.visite') is not null")
if [ "$mode" = --drop ]; then
    psql_lab -d pachadataformation -q -v ON_ERROR_STOP=1 -c 'drop schema if exists entrepot cascade' || exit 1
    echo "Schema entrepot dropped. Sync the database in Metabase to forget its tables."
    exit 0
fi
if [ "$exists" = t ] && [ "$mode" != --force ]; then
    echo "entrepot.visite already exists: nothing created (--force creates it again)."
else
    if [ "$exists" = t ]; then
        echo "Dropping the schema entrepot and everything in it (--force)."
        psql_lab -d pachadataformation -q -v ON_ERROR_STOP=1 -c 'drop schema entrepot cascade' || exit 1
    fi
    echo "Creating entrepot.visite (5 000 000 rows, a few seconds)..."
    start=$SECONDS
    psql_lab -d pachadataformation -q < setup/volume.sql || { echo "PostgreSQL refused setup/volume.sql." >&2; exit 1; }
    echo "Created in $((SECONDS - start)) s."
fi

psql_lab -d pachadataformation -v ON_ERROR_STOP=1 <<'SQL' || exit 1
\pset footer off
select count(*) as visites, sum(duree) as duree_totale_s, count(distinct visiteur) as visiteurs,
       min(jour) as premier_jour, max(jour) as dernier_jour
  from entrepot.visite;
select extract(year from jour)::int as annee, count(*) as visites
  from entrepot.visite group by 1 order by 1;
select pg_size_pretty(pg_total_relation_size('entrepot.visite')) as taille_sur_disque,
       has_table_privilege('lecture_bi', 'entrepot.visite', 'SELECT') as lu_par_lecture_bi;
SQL
