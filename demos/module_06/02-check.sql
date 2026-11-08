-- Clip 6.2. The checks of the metric "Chiffre d'affaires HT", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_06/02-check.sql

-- The metric alone: every invoice, and the part of the invoices without a date.
select sum(montantht) as chiffre_affaires_ht,
       count(*) filter (where datefacture is null) as factures_sans_date,
       sum(montantht) filter (where datefacture is null) as montant_sans_date
  from inscription.facture;

-- The metric on 2011.
select sum(montantht) as chiffre_affaires_ht_2011
  from inscription.facture
 where datefacture between date '2011-01-01' and date '2011-12-31';

-- One row of the question by company: 100 Day Loans in 2011.
select so.nom, sum(f.montantht) as chiffre_affaires_ht
  from inscription.facture f
  join (select distinct inf.facturecd, c.societeid
          from inscription.inscriptionfacture inf
          join inscription.inscription i on i.inscriptionid = inf.inscriptionid
          join contact.contact c on c.contactid = i.contactid) fs on fs.facturecd = f.facturecd
  join contact.societe so on so.societeid = fs.societeid
 where f.datefacture between date '2011-01-01' and date '2011-12-31'
   and so.nom = '100 Day Loans'
 group by so.nom;

-- The discount: entered on 9 902 invoices, none of 2011; the metric adds Montant HT before it.
select count(*) filter (where montanthtremise is not null) as factures_avec_remise,
       count(*) filter (where montanthtremise is not null
                          and datefacture between date '2011-01-01' and date '2011-12-31') as dont_2011
  from inscription.facture;
