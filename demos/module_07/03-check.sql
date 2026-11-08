-- Clip 7.3, played as lecture_bi: the numbers of the mails, written by hand.
-- 1. "Paiements par mode", in the subscription: the payments of 2011, one code, C.
select typepaiement, count(*) as paiements, sum(montant) as montant
  from inscription.suivifacture
 where datepaiement between date '2011-01-01' and date '2011-12-31'
 group by typepaiement;
-- 2. "Encaissements par période" without a value of the filter: every month that has a payment,
--    January 2012 included.
select date_trunc('month', datepaiement)::date as mois, count(*) as paiements, sum(montant) as encaisse
  from inscription.suivifacture
 group by 1
 order by 1 desc
 fetch first 2 rows only;
-- 3. The alert: invoices of 2011 without any payment, by month, and the months above 500.
select date_trunc('month', f.datefacture)::date as mois, count(*) as sans_paiement,
       count(*) > 500 as au_dessus_du_seuil
  from inscription.facture f
 where f.datefacture between date '2011-01-01' and date '2011-12-31'
   and not exists (select from inscription.suivifacture s where s.facturecd = f.facturecd)
 group by 1
 order by 1;
