-- The page of the billing service (module 11, video 11.2), written by hand.
-- SQLPage serves it at http://localhost:8080/facturation.sql and runs it as lecture_bi.
-- Each query either picks a component (the column "component") or fills the last one picked.
-- The numbers are left raw: the JSON of the page (Accept: application/json) carries them as
-- numbers, which setup/verify-page.sh compares with demos/module_11/02-references.sql.

select 'shell' as component, 'Facturation' as title, 'fr' as language;

-- An invoice without payment has no row in inscription.suivifacture.
select 'big_number' as component;
select 'Factures sans paiement' as title,
       count(*) as value,
       'sur ' || (select count(*) from inscription.facture) || ' factures' as description
  from inscription.facture f
 where not exists (select from inscription.suivifacture p where p.facturecd = f.facturecd);

-- By year of the invoice. The invoices without a date have no year: the chart leaves them out,
-- and the text below the chart says how many they are.
select 'chart' as component, 'bar' as type, 'Factures sans paiement, par année de facture' as title;
select extract(year from f.datefacture)::int as x, count(*) as y
  from inscription.facture f
 where f.datefacture is not null
   and not exists (select from inscription.suivifacture p where p.facturecd = f.facturecd)
 group by 1
 order by 1;

select 'text' as component,
       count(*) || ' factures sans date ne sont pas dans le graphique, dont '
       || count(*) filter (where not exists (select from inscription.suivifacture p
                                              where p.facturecd = f.facturecd))
       || ' sans paiement.' as contents
  from inscription.facture f
 where f.datefacture is null;

-- The ten companies with the highest amount invoiced before tax, all years. An invoice reaches
-- its company through its registrations and their contacts; it counts once per company.
select 'title' as component, 'Les dix sociétés les plus facturées' as contents, 2 as level;
select 'table' as component;
select s.nom as "Société", sum(f.montantht) as "Montant HT", count(*) as "Factures"
  from inscription.facture f
  join (select distinct i.facturecd, c.societeid
          from inscription.inscriptionfacture i
          join inscription.inscription n on n.inscriptionid = i.inscriptionid
          join contact.contact c on c.contactid = n.contactid
         where c.societeid is not null) fs on fs.facturecd = f.facturecd
  join contact.societe s on s.societeid = fs.societeid
 group by s.societeid, s.nom
 order by 2 desc, 1
 limit 10;
