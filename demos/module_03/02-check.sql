-- Clip 3.2, the check in psql: the payments of each month of 2011, as the question
-- "Encaissements par mois" shows them with its default value, then a year without payments.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_03/02-check.sql
-- Read only.

-- 1. 2011, month by month: twelve rows.
select date_trunc('month', datepaiement)::date as mois,
       count(*) as paiements,
       sum(montant) as encaisse
  from inscription.suivifacture
 where extract(year from datepaiement) = 2011
 group by 1
 order by 1;

-- 2. The years that have payments at all: 2011, and ten payments in January 2012.
select extract(year from datepaiement) as annee, count(*) as paiements, sum(montant) as encaisse
  from inscription.suivifacture
 group by 1
 order by 1;

-- 3. 2015, typed in the variable: no row, in Metabase as in psql.
select count(*) as paiements_2015
  from inscription.suivifacture
 where extract(year from datepaiement) = 2015;
