-- Clip 2.1. The keys of the database, as lecture_bi sees them (the role of Metabase):
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_02/01-keys.sql

-- The foreign keys, read in the catalog: 24, one of them on two columns.
select count(*) as cles_etrangeres,
       count(*) filter (where cardinality(conkey) > 1) as sur_plusieurs_colonnes
  from pg_constraint
 where contype = 'f';

-- The same count through information_schema: 0 under lecture_bi, which only reads. The view
-- shows the constraints of the tables a role owns or may change, not of those it only reads.
select count(*) as vues_par_information_schema
  from information_schema.table_constraints
 where constraint_type in ('FOREIGN KEY', 'PRIMARY KEY');

-- The primary keys, read in the catalog: 93.
select count(*) as cles_primaires from pg_constraint where contype = 'p';

-- The key on two columns, and the column of inscription that points to a session without a
-- foreign key.
select conrelid::regclass as table_source, confrelid::regclass as table_cible,
       (select string_agg(attname, ', ') from pg_attribute
         where attrelid = conrelid and attnum = any (conkey)) as colonnes
  from pg_constraint
 where contype = 'f' and conrelid = 'stage.session'::regclass and cardinality(conkey) > 1;

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
