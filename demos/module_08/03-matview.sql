-- Clip 8.3. The pre-aggregation: a materialized view of the visits by month, computed once by
-- PostgreSQL and stored, which the card by month reads instead of the 5 000 000 rows of
-- entrepot.visite. Run as postgres, the owner of entrepot; lecture_bi reads the view through
-- the default privileges of ./setup/install.sh, without a grant:
-- docker compose exec -T db psql -U postgres -d pachadataformation < demos/module_08/03-matview.sql
-- The view keeps the numbers of the moment it was computed: refresh materialized view
-- entrepot.visites_par_mois; computes them again (a few seconds), when the table has changed.
\timing on
drop materialized view if exists entrepot.visites_par_mois;
create materialized view entrepot.visites_par_mois as
select cast(date_trunc('month', jour) as date) as mois,
       count(*) as visites,
       count(distinct visiteur) as visiteurs
  from entrepot.visite
 group by 1;
comment on materialized view entrepot.visites_par_mois is
    'Visits and distinct visitors by month, from entrepot.visite. Visitors add up over the visits of a month only, never over several months.';
refresh materialized view entrepot.visites_par_mois;
\timing off
select count(*) as mois, sum(visites) as visites,
       pg_size_pretty(pg_total_relation_size('entrepot.visites_par_mois')) as taille,
       has_table_privilege('lecture_bi', 'entrepot.visites_par_mois', 'SELECT') as lue_par_lecture_bi
  from entrepot.visites_par_mois;
