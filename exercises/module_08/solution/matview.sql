-- Exercise 08, the materialized view: the visits and the time spent on the pages by month and
-- by course, computed once from entrepot.visite. Visits and seconds add up from the months to
-- the years, so a question by year can read it. Run as postgres, the owner of entrepot:
-- docker compose exec -T db psql -U postgres -d pachadataformation < exercises/module_08/solution/matview.sql
drop materialized view if exists entrepot.visites_par_stage;
create materialized view entrepot.visites_par_stage as
select cast(date_trunc('month', jour) as date) as mois,
       stageid,
       count(*) as visites,
       sum(duree) as duree
  from entrepot.visite
 group by 1, 2;
