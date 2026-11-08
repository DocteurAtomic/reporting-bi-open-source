-- Clip 9.2: the turnover of 2011, written by hand, against the answer of Metabot (22 486 000,
-- before tax). Same table, same column, same filter on the invoice date; the reading with tax
-- comes next to it, and the 105 invoices without a date belong to no year.
-- Run as lecture_bi: docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_09/02-check.sql
select count(*) as factures, sum(montantht) as chiffre_affaires_ht, sum(montantttc) as chiffre_affaires_ttc
  from inscription.facture
 where datefacture >= date '2011-01-01' and datefacture < date '2012-01-01';

select count(*) as factures_sans_date
  from inscription.facture
 where datefacture is null;
