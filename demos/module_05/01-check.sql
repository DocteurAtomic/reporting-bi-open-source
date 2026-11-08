-- Clip 5.1, the check in psql of the cards of "Tableau de bord de la facturation", without
-- a filter.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_05/01-check.sql
-- Read only.

-- 1. Payments exist for two years only.
select extract(year from datepaiement)::int as annee, count(*) as paiements, sum(montant) as montant
  from inscription.suivifacture
 group by 1
 order by 1;

-- 2. The invoices without payment, by year of invoice: before 2011 every invoice of the year,
--    in 2011 two thirds of them; the invoices without a date apart.
select extract(year from f.datefacture)::int as annee,
       count(*) as factures,
       count(*) filter (where not exists (select from inscription.suivifacture s
                                           where s.facturecd = f.facturecd)) as sans_paiement
  from inscription.facture f
 group by 1
 order by 1 desc nulls first
 limit 4;

-- 3. The years where the two counts differ, and the totals.
select count(distinct extract(year from datefacture)) as annees,
       count(*) filter (where datefacture is null) as sans_date,
       count(*) filter (where not exists (select from inscription.suivifacture s
                                           where s.facturecd = f.facturecd)) as sans_paiement,
       count(*) as factures
  from inscription.facture f;
