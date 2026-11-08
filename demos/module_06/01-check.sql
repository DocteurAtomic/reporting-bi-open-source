-- Clip 6.1. The checks of the model "Factures", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_06/01-check.sql

-- The two totals of 2011: the invoices, and each invoice once per stage it covers (the rows of
-- "Chiffre d'affaires par stage" under the filter 2011, added up).
select count(*) as factures_2011, sum(montantht) as montant_ht_2011
  from inscription.facture
 where datefacture between date '2011-01-01' and date '2011-12-31';

with paires as (
    select distinct f.facturecd, f.montantht, sl.titre
      from inscription.facture f
      join inscription.inscriptionfacture inf on inf.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = inf.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
      join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
     where f.datefacture between date '2011-01-01' and date '2011-12-31')
select count(*) as paires_facture_stage, count(distinct titre) as stages, sum(montantht) as somme_des_stages
  from paires;

-- The model has one row per invoice only if no invoice has two companies.
select count(*) as factures from inscription.facture;

select nb_societes, count(*) as factures
  from (select f.facturecd, count(distinct c.societeid) as nb_societes
          from inscription.facture f
          left join inscription.inscriptionfacture inf on inf.facturecd = f.facturecd
          left join inscription.inscription i on i.inscriptionid = inf.inscriptionid
          left join contact.contact c on c.contactid = i.contactid
         group by f.facturecd) x
 group by nb_societes
 order by nb_societes;

-- One row checked: the company with the most invoices in 2011.
select so.nom, count(distinct f.facturecd) as factures
  from inscription.facture f
  join inscription.inscriptionfacture inf on inf.facturecd = f.facturecd
  join inscription.inscription i on i.inscriptionid = inf.inscriptionid
  join contact.contact c on c.contactid = i.contactid
  join contact.societe so on so.societeid = c.societeid
 where f.datefacture between date '2011-01-01' and date '2011-12-31'
 group by so.nom
 order by factures desc, so.nom
 limit 3;
