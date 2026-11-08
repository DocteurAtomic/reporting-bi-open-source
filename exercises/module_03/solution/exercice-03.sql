-- Solution of exercise 03, typed in the SQL editor of Metabase on pachadataformation.
-- The variable periode: type Field filter, mapped to Facture > Datefacture (the table facture,
-- not facturecolumnstore), widget with all the date options, default value from 2011-01-01
-- to 2011-12-31. Saved as "Exercice 03". Copy only the query below into Metabase.
select count(*) as factures,
       sum(montantht) as montant_ht
  from inscription.facture
 where {{periode}}
