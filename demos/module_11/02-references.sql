-- check: page facturation.sql
-- The references of the billing page (videos 11.2 to 11.4), one query per component, written
-- apart from the page: an anti-join where the page uses not exists, a left join for the
-- companies. setup/verify-page.sh asks the page in JSON and compares each query with the rows
-- of one component. Run it with ./demos/module_11/04-verify.sh, or alone in psql to read the
-- numbers.

-- component: Factures sans paiement
-- 14 343 invoices out of 16 514 have no payment at all.
select count(*) as sans_paiement
  from inscription.facture f
  left join (select distinct facturecd from inscription.suivifacture) p on p.facturecd = f.facturecd
 where p.facturecd is null;

-- component: Factures sans paiement par année
-- 56 years, from 1953 to 2011 (none from 2008 to 2010): 4 343 in 2011, 206 in 2007. The 105
-- invoices without a date have no year and are left out.
select extract(year from f.datefacture)::int as annee, count(*) as sans_paiement
  from inscription.facture f
  left join (select distinct facturecd from inscription.suivifacture) p on p.facturecd = f.facturecd
 where p.facturecd is null and f.datefacture is not null
 group by 1
 order by 1;

-- component: Les dix sociétés les plus facturées
-- All years, before tax: 100 Day Loans 41 835 366,79 (981 invoices) first, Approval Department
-- 5 158 008,30 tenth; the eleventh, Bamboo Flooring, has 4 674 605,49. No invoice reaches two
-- companies, so an invoice is counted once.
select nom, montant_ht, factures
  from (select s.nom, sum(f.montantht) as montant_ht, count(*) as factures,
               rank() over (order by sum(f.montantht) desc) as rang
          from contact.societe s
          join inscription.facture f
            on exists (select from inscription.inscriptionfacture x
                         join inscription.inscription i on i.inscriptionid = x.inscriptionid
                         join contact.contact c on c.contactid = i.contactid
                        where x.facturecd = f.facturecd and c.societeid = s.societeid)
         group by s.societeid, s.nom) r
 where rang <= 10
 order by montant_ht desc;
