-- Clip 2.1. The keys of the database, as lecture_bi sees them (the role of Metabase):
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_02/01-keys.sql

-- The primary and foreign keys of the tables of the course, read in the catalog (the system
-- catalogs left out): 31 primary keys, 4 of them on two columns; 24 foreign keys, 1 of them
-- on two columns.
select c.contype, count(*) as cles,
       count(*) filter (where cardinality(c.conkey) > 1) as sur_plusieurs_colonnes
  from pg_constraint c
  join pg_namespace n on n.oid = c.connamespace
 where c.contype in ('p', 'f') and n.nspname not in ('pg_catalog', 'information_schema')
 group by c.contype
 order by c.contype;

-- The same keys through information_schema, where Metabase reads them. The view shows only
-- the constraints of the tables on which the role has a privilege other than select:
-- lecture_bi has references on the schemas of the course, so it sees them.
select constraint_type, count(*) as vues_par_information_schema
  from information_schema.table_constraints
 where constraint_type in ('FOREIGN KEY', 'PRIMARY KEY')
 group by constraint_type
 order by constraint_type;

-- The foreign key on two columns: session to stagelangue, by stageid and languecd.
select conrelid::regclass as table_source, confrelid::regclass as table_cible,
       (select string_agg(attname, ', ' order by attname) from pg_attribute
         where attrelid = conrelid and attnum = any (conkey)) as colonnes
  from pg_constraint
 where contype = 'f' and conrelid = 'stage.session'::regclass and cardinality(conkey) > 1;

-- One language per stage: stageid alone designates one row of stagelangue.
select count(*) as lignes, count(distinct stageid) as stages, count(distinct languecd) as langues
  from stage.stagelangue;

-- The registrations whose session does not exist: why the database declares no foreign key
-- from inscription.sessionid to session.
select count(*) as inscriptions_sans_session
  from inscription.inscription i
 where not exists (select from stage.session s where s.sessionid = i.sessionid);

-- What the fixed join gives: sessions by stage title, first rows.
select sl.titre, count(*) as sessions
  from stage.session s
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
 group by sl.titre
 order by sessions desc, sl.titre
 limit 3;
