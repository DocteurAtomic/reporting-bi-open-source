-- Clip 10.4, written before the request is given to Claude Code: the reference of each card of
-- the dashboard it is asked to build, "m10-Tableau de bord de la facturation", for
-- setup/verify-dashboard.sh (04-verify.sh). One query per card, after its line "-- card:", with
-- the columns the request names; :'debut' and :'fin' are the two ends of the value given to the
-- filter "Période". The same demands as the dashboard of module 5, without the fixed filter on
-- 2011 of its card of payments. Read only. To run one alone in psql: \set debut 2011-01-01 then
-- \set fin 2011-12-31.
-- check: filter 2011-01-01~2011-12-31

-- card: Factures sans paiement par année
-- The invoices with no row in suivifacture, by year of invoice; the 105 invoices without a date
-- are left out, as the filter on the date leaves them out.
select date_trunc('year', f.datefacture)::date as annee, count(*) as factures
  from inscription.facture f
 where not exists (select from inscription.suivifacture s where s.facturecd = f.facturecd)
   and f.datefacture between :'debut' and :'fin'
 group by 1;

-- card: Chiffre d'affaires HT par stage
-- Each invoice counted once for each course it bills registrations of; the invoices of the
-- period without a session make a line without a title.
select titre, sum(montantht) as montant_ht
  from (select distinct f.facturecd, f.montantht, sl.titre
          from inscription.facture f
          left join inscription.inscriptionfacture inf on inf.facturecd = f.facturecd
          left join inscription.inscription i on i.inscriptionid = inf.inscriptionid
          left join stage.session s on s.sessionid = i.sessionid
          left join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
         where f.datefacture between :'debut' and :'fin') ft
 group by titre;

-- card: Paiements par mode
-- The code of the mode, its label (empty: the code C of the payments of 2011 has no row in
-- reference.modepaiement), the number of payments and their amount.
select s.typepaiement, m.libelle, count(*) as paiements, sum(s.montant) as montant
  from inscription.suivifacture s
  left join reference.modepaiement m on m.modepaiementcd = s.typepaiement
 where s.datepaiement between :'debut' and :'fin'
 group by 1, 2;

-- card: Encaissements par mois
select date_trunc('month', datepaiement)::date as mois, count(*) as paiements, sum(montant) as encaisse
  from inscription.suivifacture
 where datepaiement between :'debut' and :'fin'
 group by 1;
