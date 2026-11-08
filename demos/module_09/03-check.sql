-- Clip 9.3: the three answers asked while the sample database was back, recomputed in the
-- database of the organisation: the payments received in 2011, the average discount of the
-- invoices, and the courses of the catalogue.
-- Run as lecture_bi: docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_09/03-check.sql
select sum(montant) as encaisse_2011
  from inscription.suivifacture
 where datepaiement >= date '2011-01-01' and datepaiement < date '2012-01-01';

select round(avg(remise), 2) as remise_moyenne_factures, count(remise) as factures_avec_remise, count(*) as factures
  from inscription.facture;

select count(*) as stages from stage.stage;
