-- check: card
-- Exercise 02: the ten stages that have the most invoices, each invoice counted once per stage.
-- The order of the rows is not checked: the sixth and seventh stages (179 invoices) and the
-- ninth and tenth (163) are tied, and the query builder may list them either way. The
-- eleventh has 162, so the ten rows themselves do not depend on the order.
select sl.titre, count(distinct fi.facturecd) as factures
  from inscription.inscriptionfacture fi
  join inscription.inscription i on i.inscriptionid = fi.inscriptionid
  join stage.session s on s.sessionid = i.sessionid
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
 group by sl.titre
 order by factures desc
 limit 10;
