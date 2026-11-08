-- Clip 3.3, the check in psql: April 2011 chosen in the date widget of the field filter
-- {{periode}}, then the field filter left empty.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_03/03-check.sql
-- Read only.

-- 1. April 2011, written as Metabase writes it (see 03-compiled-sql.sh): one row.
select date_trunc('month', datepaiement)::date as mois,
       count(*) as paiements,
       sum(montant) as encaisse
  from inscription.suivifacture
 where datepaiement between date '2011-04-01' and date '2011-04-30'
 group by 1
 order by 1;

-- 2. No value in the widget: Metabase replaces the field filter with 1 = 1, so every payment
--    counts, thirteen months from January 2011 to January 2012.
select count(*) as mois, sum(paiements) as paiements, sum(encaisse) as encaisse
  from (select date_trunc('month', datepaiement) as mois, count(*) as paiements, sum(montant) as encaisse
          from inscription.suivifacture
         group by 1) m;
