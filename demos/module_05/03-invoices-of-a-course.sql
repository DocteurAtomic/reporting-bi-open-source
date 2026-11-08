-- Clip 5.3. "Factures d'un stage": the invoices of one course, one row per invoice, for the
-- destination of the click on the table "Chiffre d'affaires par stage". Two field filters:
-- {{stage}} on Stagelangue > Titre (table alias sl.titre) and {{periode}} on Facture >
-- Datefacture (alias f.datefacture). Typed in the SQL editor of Metabase; the sum of montantht
-- is the amount of the clicked line.
select f.facturecd, f.datefacture, f.montantht
  from inscription.facture f
 where exists (select
                 from inscription.inscriptionfacture inf
                 join inscription.inscription i on i.inscriptionid = inf.inscriptionid
                 join stage.session s on s.sessionid = i.sessionid
                 join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
                where inf.facturecd = f.facturecd
                  and {{stage}})
   and {{periode}}
 order by f.datefacture, f.facturecd
