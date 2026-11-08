#!/usr/bin/env bash
# Sets up the lab:
# 1. writes .env from .env.example and fills the empty passwords (postgres, metabase,
#    lecture_bi) with random values, never printed;
# 2. downloads the pachadataformation dump if it is missing and checks its SHA-256;
# 3. starts PostgreSQL, restores the database under a temporary name, moves every email
#    address to a reserved .example domain, compacts the tables (VACUUM FULL, then ANALYZE)
#    and renames the database;
# 4. creates the role lecture_bi, which can only connect, use the schemas and read the tables,
#    today and tomorrow (default privileges), and the application database of Metabase;
# 5. starts Metabase and waits for /api/health.
# It does not create the administrator account of Metabase: module 1 does it in the browser.
# Usage: ./setup/install.sh
#   Docker is used when it is installed, Podman otherwise. Override with ENGINE and COMPOSE,
#   for instance: COMPOSE="podman-compose" ./setup/install.sh
# Running it again is safe: .env, the dump, the database and the roles are kept (the passwords
# of the roles are set again to the values of .env).
set -euo pipefail
cd "$(dirname "$0")/.."
start=$SECONDS

# 1. The passwords. They live in .env only (ignored by git), never in a committed file, and
# reach awk through its environment, not its command line.
pw() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true; }
umask 077
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Wrote .env from .env.example."
fi
NEW_PG=$(pw) NEW_MB=$(pw) NEW_RO=$(pw) awk '
    /^POSTGRES_PASSWORD=$/   { print "POSTGRES_PASSWORD=" ENVIRON["NEW_PG"]; n++; next }
    /^MB_DB_PASS=$/          { print "MB_DB_PASS=" ENVIRON["NEW_MB"]; n++; next }
    /^LECTURE_BI_PASSWORD=$/ { print "LECTURE_BI_PASSWORD=" ENVIRON["NEW_RO"]; n++; next }
    { print }
    END { if (n) print n " empty password(s) of .env filled with random values." > "/dev/stderr" }' .env > .env.new
mv .env.new .env
umask 022
. setup/lib.sh

# 2. The dump, checked against its SHA-256.
url='https://files.pachadata.com/public/api/raw?hash=detKgDWpmgcSvphD4YTPvQ&file=%2Fsample-databases%2FPachadataFormation%2FPostgreSQL%2Fpachadataformation.pgdump'
sum=96df4039dcd2faffe59707e61031e9ccaed40f482827daa346f23b448eca4197
dump=setup/pachadataformation.pgdump
if [ ! -f "$dump" ]; then
    echo "Downloading the database dump (23 MB)..."
    curl -fL --retry 3 -o "$dump.part" "$url"
    mv "$dump.part" "$dump"
fi
if command -v sha256sum >/dev/null; then got=$(sha256sum "$dump" | cut -d' ' -f1)
else got=$(shasum -a 256 "$dump" | cut -d' ' -f1); fi
if [ "$got" != "$sum" ]; then
    echo "Checksum mismatch for $dump: delete it and run this script again." >&2
    exit 1
fi

# 3. PostgreSQL. A port already taken by another program fails here with a clear message
# rather than inside compose. The wait loops do not rely on "compose up --wait", which
# podman-compose lacks.
port_taken() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
if ! lab_running "$c" && port_taken "$port"; then
    echo "Port $port of 127.0.0.1 is already taken. Set PGPORT in .env to a free port and run this script again." >&2
    exit 1
fi
if ! lab_running "$mbc" && port_taken "$mbport"; then
    echo "Port $mbport of 127.0.0.1 is already taken. Set MBPORT in .env to a free port and run this script again." >&2
    exit 1
fi
mkdir -p work
$compose up -d db
echo -n "Waiting for PostgreSQL"
for _ in $(seq 1 60); do
    if $engine exec "$c" pg_isready -U postgres -h 127.0.0.1 -q 2>/dev/null; then echo " ready."; break; fi
    echo -n "."; sleep 1
done
$engine exec "$c" pg_isready -U postgres -h 127.0.0.1 -q

# Restored under a temporary name and renamed at the end: an interrupted run leaves only the
# temporary database, which the next run drops and restores again.
if [ "$(psql_lab -At -c "select 1 from pg_database where datname = 'pachadataformation'")" = 1 ]; then
    echo "The database pachadataformation already exists: nothing to restore."
else
    tmp=pachadataformation_restore
    step=$SECONDS
    $engine exec "$c" dropdb -U postgres --if-exists $tmp
    $engine exec "$c" createdb -U postgres -T template0 $tmp
    $engine exec "$c" pg_restore -U postgres -d $tmp --no-owner /setup/pachadataformation.pgdump
    echo "Restored in $((SECONDS - step)) s."
    step=$SECONDS
    psql_lab -d $tmp -q -v ON_ERROR_STOP=1 < setup/anonymize.sql
    echo "Email addresses moved to .example in $((SECONDS - step)) s."
    # The anonymization rewrites every row of contact.prospectus and doubles its size:
    # VACUUM FULL gives the tables the size of tables never written to.
    step=$SECONDS
    psql_lab -d $tmp -q -v ON_ERROR_STOP=1 -c "vacuum full" -c "analyze"
    echo "VACUUM FULL and ANALYZE in $((SECONDS - step)) s."
    psql_lab -q -v ON_ERROR_STOP=1 -c "alter database $tmp rename to pachadataformation"
fi

# 4. The roles. The passwords travel on the standard input of psql, as psql variables, never
# on a command line.
{
    echo '\set ON_ERROR_STOP on'
    echo "\\set ro_pw $(sql_text "$LECTURE_BI_PASSWORD")"
    echo "\\set mb_pw $(sql_text "$MB_DB_PASS")"
    cat <<'SQL'
-- lecture_bi: Metabase and SQLPage read pachadataformation through it.
select format('create role lecture_bi login password %L', :'ro_pw')
 where not exists (select from pg_roles where rolname = 'lecture_bi') \gexec
select format('alter role lecture_bi login password %L', :'ro_pw') \gexec
-- metabase: owner of the application database of Metabase, which it alone writes.
select format('create role metabase login password %L', :'mb_pw')
 where not exists (select from pg_roles where rolname = 'metabase') \gexec
select format('alter role metabase login password %L', :'mb_pw') \gexec
select 'create database metabase owner metabase'
 where not exists (select from pg_database where datname = 'metabase') \gexec
-- Every role may connect to every database by default (PUBLIC): the lab says who may.
revoke connect on database metabase from public;
revoke connect on database pachadataformation from public;
grant connect on database pachadataformation to lecture_bi;
\connect pachadataformation
-- Usage on every schema of the organization, select and references on every table, nothing
-- else. References lets no one write: lecture_bi creates no table to hold a foreign key. It
-- is there because information_schema shows a constraint only to a role with a privilege
-- other than select, and Metabase reads the keys there: with select alone, it sees no
-- primary key at all (measured on 0.65.3, 8 November 2026).
select format('grant usage on schema %I to lecture_bi', nspname)
     || format('; grant select, references on all tables in schema %I to lecture_bi', nspname)
  from pg_namespace
 where nspname not in ('pg_catalog', 'information_schema', 'pg_toast')
   and nspname not like 'pg\_temp\_%' and nspname not like 'pg\_toast\_temp\_%' \gexec
-- The same for the schemas and tables postgres creates later (module 8 adds the schema entrepot).
alter default privileges for role postgres grant usage on schemas to lecture_bi;
alter default privileges for role postgres grant select, references on tables to lecture_bi;
SQL
} | psql_lab -d postgres -q
echo "Role lecture_bi and database metabase ready."

# 5. Metabase. Its first start creates its tables in the database metabase: about half a
# minute once the image is downloaded.
step=$SECONDS
$compose up -d metabase
echo -n "Waiting for Metabase on $mb_url"
for _ in $(seq 1 180); do
    if mb_healthy; then echo " ready."; break; fi
    echo -n "."; sleep 2
done
if ! mb_healthy; then
    echo " Metabase does not answer: read its log with $engine logs $mbc" >&2
    exit 1
fi
echo "Metabase answered in $((SECONDS - step)) s."

psql_lab -d pachadataformation -At -c "
select count(*) || ' tables, '
       || pg_size_pretty(pg_database_size('pachadataformation')) || ', '
       || (select (select count(*) from contact.contact where email !~ '\.example$' or email2 !~ '\.example$')
                + (select count(*) from contact.prospectus where email !~ '\.example$')
                + (select count(*) from formateur.societeformateur where emailcontact !~ '\.example$')
                + (select count(*) from reference.lieuformation where emailcontact !~ '\.example$'))
       || ' email address outside .example'
  from pg_tables where schemaname not in ('pg_catalog', 'information_schema')"
echo "Companies read by lecture_bi: $(psql_lab -d pachadataformation -qAt -c 'set role lecture_bi' -c 'select count(*) from contact.societe')"
echo "Lab ready in $((SECONDS - start)) s."
echo "Metabase: http://localhost:$mbport (module 1 creates the administrator account)."
echo "psql: $compose exec db psql -U postgres -d pachadataformation"
