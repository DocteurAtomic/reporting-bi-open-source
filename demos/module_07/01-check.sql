-- Clip 7.1, played as lecture_planning, the role of the connection "Données du planning":
--   docker compose exec -T db psql -U lecture_planning -d pachadataformation < demos/module_07/01-check.sql
-- The second count is refused by PostgreSQL itself: whatever Metabase lets a group do on this
-- connection, the role cannot read the invoices. The script goes on after the error.
\set ON_ERROR_STOP off
select current_user;
select count(*) as sessions from stage.session;
select count(*) as factures from inscription.facture;
-- What each role of the lab reads, schema by schema.
select r.rolname as role, n.nspname as schema, count(*) as tables
  from pg_roles r
  join pg_class c on c.relkind in ('r', 'p') and has_table_privilege(r.oid, c.oid, 'select')
  join pg_namespace n on n.oid = c.relnamespace
 where r.rolname in ('lecture_bi', 'lecture_planning', 'lecture_facturation')
   and n.nspname not in ('pg_catalog', 'information_schema')
 group by 1, 2
 order by 1, 2;
