-- Clip 8.3. The checks of the materialized view entrepot.visites_par_mois, run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_08/03-check.sql
\timing on

-- The view and the fact table give the same total, and the same row for December 2020.
select (select sum(visites) from entrepot.visites_par_mois) as visites_vue,
       (select count(*) from entrepot.visite) as visites_table;
select v.visites, v.visiteurs,
       (select count(*) from entrepot.visite where jour between date '2020-12-01' and date '2020-12-31') as visites_table,
       (select count(distinct visiteur) from entrepot.visite where jour between date '2020-12-01' and date '2020-12-31') as visiteurs_table
  from entrepot.visites_par_mois v
 where v.mois = date '2020-12-01';

-- What the view cannot answer: the visitors of a year. The visitors of the twelve months of
-- 2020 added up count several times a visitor who came back in another month.
select (select sum(visiteurs) from entrepot.visites_par_mois
         where mois between date '2020-01-01' and date '2020-12-01') as somme_des_mois,
       (select count(distinct visiteur) from entrepot.visite
         where jour between date '2020-01-01' and date '2020-12-31') as visiteurs_2020;
