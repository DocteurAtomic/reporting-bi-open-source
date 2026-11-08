-- Clip 3.3: the same payments for the period chosen in the field filter {{periode}}
-- (variable type: Field filter, mapped to Suivifacture > Datepaiement, widget: all options).
-- No column and no operator after where: Metabase writes the condition. For the SQL editor of
-- Metabase only; the check is 03-check.sql.
-- Saved in Metabase as "Encaissements par période".
select date_trunc('month', datepaiement)::date as mois,
       count(*) as paiements,
       sum(montant) as encaisse
  from inscription.suivifacture
 where {{periode}}
 group by 1
 order by 1
