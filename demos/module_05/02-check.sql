-- Clip 5.2, the check in psql of the cards filtered on 2011, then of the card that the filter
-- does not reach.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_05/02-check.sql
-- Read only.

-- 1. 2011: invoices without payment, invoices and their total, payments, cash received.
select (select count(*) from inscription.facture f
         where f.datefacture between date '2011-01-01' and date '2011-12-31'
           and not exists (select from inscription.suivifacture s where s.facturecd = f.facturecd)) as sans_paiement,
       (select count(distinct sl.titre)
          from inscription.facture f
          join inscription.inscriptionfacture inf on inf.facturecd = f.facturecd
          join inscription.inscription i on i.inscriptionid = inf.inscriptionid
          join stage.session s on s.sessionid = i.sessionid
          join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
         where f.datefacture between date '2011-01-01' and date '2011-12-31') as stages,
       (select count(*) from inscription.suivifacture
         where datepaiement between date '2011-01-01' and date '2011-12-31') as paiements,
       (select sum(montant) from inscription.suivifacture
         where datepaiement between date '2011-01-01' and date '2011-12-31') as encaisse;

-- 2. 2012: what "Encaissements par période" shows, and "Encaissements par mois" does not.
select date_trunc('month', datepaiement)::date as mois, count(*) as paiements, sum(montant) as encaisse
  from inscription.suivifacture
 where datepaiement between date '2012-01-01' and date '2012-12-31'
 group by 1;
