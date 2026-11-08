-- Clip 2.2. The check of "Paiements par mode", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_02/02-payments-by-mode.sql
-- The payment codes of the whole table.
select typepaiement, count(*) as paiements, sum(montant) as montant,
       min(datepaiement) as premier, max(datepaiement) as dernier
  from inscription.suivifacture
 group by typepaiement;

-- The same, for 2011 only: what the question shows.
select typepaiement, count(*) as paiements, sum(montant) as montant
  from inscription.suivifacture
 where datepaiement between date '2011-01-01' and date '2011-12-31'
 group by typepaiement;

-- The modes the reference table knows.
select modepaiementcd, libelle from reference.modepaiement order by modepaiementcd;

-- The payments whose code is in the reference table: none.
select count(*) as rattaches
  from inscription.suivifacture sf
  join reference.modepaiement mp on mp.modepaiementcd = sf.typepaiement;
