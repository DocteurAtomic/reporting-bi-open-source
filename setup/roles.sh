#!/usr/bin/env bash
# Module 7: creates the two PostgreSQL roles that give each service its own connection in
# Metabase, because the open-source edition of Metabase sets data permissions per database and
# not per schema. Each role can connect to pachadataformation and read its own tables, nothing
# else:
#   lecture_planning     the schema stage, and the rooms and places of reference
#                        (salleformation, lieuformation)
#   lecture_facturation  the schema inscription, and the payment modes of reference
#                        (modepaiement)
# Their passwords are drawn at random into .env (LECTURE_PLANNING_PASSWORD,
# LECTURE_FACTURATION_PASSWORD) when they are empty there, never printed, and reach psql on its
# standard input. They get select and references, like lecture_bi: without references,
# information_schema hides the constraints of a table, and Metabase sees no primary key.
# Tables created later are not granted to them (no default privileges): module 8 adds the
# schema entrepot for lecture_bi only.
# Usage: ./setup/roles.sh (after ./setup/install.sh). Running it again is safe: the roles are
# kept and their passwords set again to the values of .env.
set -euo pipefail
cd "$(dirname "$0")/.."
pw() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true; }
[ -f .env ] || { echo "No .env: run ./setup/install.sh first." >&2; exit 1; }
umask 077
for key in LECTURE_PLANNING_PASSWORD LECTURE_FACTURATION_PASSWORD; do
    grep -q "^$key=" .env || printf '%s=\n' "$key" >> .env
done
NEW_PL=$(pw) NEW_FA=$(pw) awk '
    /^LECTURE_PLANNING_PASSWORD=$/    { print "LECTURE_PLANNING_PASSWORD=" ENVIRON["NEW_PL"]; n++; next }
    /^LECTURE_FACTURATION_PASSWORD=$/ { print "LECTURE_FACTURATION_PASSWORD=" ENVIRON["NEW_FA"]; n++; next }
    { print }
    END { if (n) print n " empty password(s) of .env filled with random values." > "/dev/stderr" }' .env > .env.new
mv .env.new .env
umask 022
. setup/lib.sh
lab_running "$c" || { echo "The container $c is not running: start the lab with ./setup/install.sh." >&2; exit 1; }

{
    echo '\set ON_ERROR_STOP on'
    echo "\\set pl_pw $(sql_text "$LECTURE_PLANNING_PASSWORD")"
    echo "\\set fa_pw $(sql_text "$LECTURE_FACTURATION_PASSWORD")"
    cat <<'SQL'
select format('create role %I login password %L', r, p)
  from (values ('lecture_planning', :'pl_pw'), ('lecture_facturation', :'fa_pw')) v(r, p)
 where not exists (select from pg_roles where rolname = r) \gexec
alter role lecture_planning login password :'pl_pw';
alter role lecture_facturation login password :'fa_pw';
grant connect on database pachadataformation to lecture_planning, lecture_facturation;
\connect pachadataformation
-- The planning: the courses, their sessions and languages, the rooms and the places.
grant usage on schema stage, reference to lecture_planning;
grant select, references on all tables in schema stage to lecture_planning;
grant select, references on reference.salleformation, reference.lieuformation to lecture_planning;
-- The invoicing: registrations, invoices, payments, and the names of the payment modes.
grant usage on schema inscription, reference to lecture_facturation;
grant select, references on all tables in schema inscription to lecture_facturation;
grant select, references on reference.modepaiement to lecture_facturation;
SQL
} | psql_lab -d postgres -q
psql_lab -d pachadataformation -At -F ' ' -c "
select r, count(*) || ' tables: ' || string_agg(t, ', ' order by t)
  from (values ('lecture_planning'), ('lecture_facturation')) v(r),
       lateral (select schemaname || '.' || tablename as t from pg_tables
                 where schemaname not in ('pg_catalog', 'information_schema')
                   and has_table_privilege(r, format('%I.%I', schemaname, tablename), 'SELECT')) x
 group by r order by r desc"
