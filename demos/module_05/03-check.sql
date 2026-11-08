-- Clip 5.3, the check in psql of the two clicks: the bar of 2007 in "Factures sans paiement
-- par année", then the course "SQL Server 2005 Expertise" in "Chiffre d'affaires par stage"
-- with the filter on 2011.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_05/03-check.sql
-- Read only.

-- 1. The invoices of 2007 without payment: the rows of the detail opened by the click.
select count(*) as factures
  from inscription.facture f
 where f.datefacture between date '2007-01-01' and date '2007-12-31'
   and not exists (select from inscription.suivifacture s where s.facturecd = f.facturecd);

-- 2. The invoices of the course in 2011, each counted once: the rows of "Factures d'un stage".
select count(*) as factures, sum(f.montantht) as montant_ht
  from inscription.facture f
 where f.datefacture between date '2011-01-01' and date '2011-12-31'
   and exists (select
                 from inscription.inscriptionfacture inf
                 join inscription.inscription i on i.inscriptionid = inf.inscriptionid
                 join stage.session s on s.sessionid = i.sessionid
                 join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
                where inf.facturecd = f.facturecd and sl.titre = 'SQL Server 2005 Expertise');
