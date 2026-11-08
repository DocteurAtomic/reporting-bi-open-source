-- Clip 8.1. The checks of the dashboard "Visites du catalogue", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_08/01-check.sql

-- The totals that ./setup/volume.sh prints: 5 000 000 visits, the same number as the cards add up.
select count(*) as visites, count(distinct visiteur) as visiteurs, sum(duree) as duree_totale_s
  from entrepot.visite;

-- A known row of the card by month: December 2020.
select count(*) as visites, count(distinct visiteur) as visiteurs
  from entrepot.visite
 where jour between date '2020-12-01' and date '2020-12-31';

-- The SQL that Metabase sends for "Visites et visiteurs par mois" (01-dashboard.sh prints it),
-- run under EXPLAIN ANALYZE: where the time goes.
explain (analyze, buffers, costs off)
select cast(date_trunc('month', jour) as date) as jour, count(*), count(distinct visiteur)
  from entrepot.visite
 group by cast(date_trunc('month', jour) as date)
 order by 1;
