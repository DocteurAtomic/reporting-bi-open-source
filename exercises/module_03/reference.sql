-- check: card
-- check: parameter dimension periode date/all-options 2007-01-01~2007-12-31
-- Exercise 03: the number of invoices and their total before tax, for the period chosen in
-- the field filter {{periode}}, mapped to the column datefacture of inscription.facture.
-- check.sh runs the question "Exercice 03" with the period of 2007, and not with the default
-- value of the exercise (2011): a question that ignores its filter, or filters another
-- column, gives 2011 the right numbers and 2007 wrong ones.
select count(*) as factures,
       sum(montantht) as montant_ht
  from inscription.facture
 where datefacture between date '2007-01-01' and date '2007-12-31';
