-- Clip 1.3: how many tables should the data browser of Metabase show? Counts the tables of
-- pachadataformation outside the two schemas of the system catalog, under lecture_bi.
-- Read only. Expected: 34, in seven schemas.
select count(*)
  from pg_tables
 where schemaname not in ('pg_catalog', 'information_schema');

select schemaname, count(*)
  from pg_tables
 where schemaname not in ('pg_catalog', 'information_schema')
 group by schemaname
 order by schemaname;
