-- Clip 3.2: the payments received each month of the year typed in the variable {{annee}}
-- (variable type: Number, default value 2011, required). For the SQL editor of Metabase only:
-- psql does not know {{annee}}; the check is 02-check.sql.
-- Saved in Metabase as "Encaissements par mois".
select date_trunc('month', datepaiement)::date as mois,
       count(*) as paiements,
       sum(montant) as encaisse
  from inscription.suivifacture
 where extract(year from datepaiement) = {{annee}}
 group by 1
 order by 1
