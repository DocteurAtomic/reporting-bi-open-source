-- check: card
-- check: metric Encaissements
-- Exercise 06: the payments received in 2011, by the date of payment, through a saved metric
-- "Encaissements" (the sum of suivifacture.montant). 2 161 payments, 8 846 812. The check runs
-- the question "Exercice 06", compares its single row with this query, then reads the question
-- to see that its summary is the metric and not a sum written again.
select sum(montant) as encaissements
  from inscription.suivifacture
 where datepaiement between date '2011-01-01' and date '2011-12-31';
