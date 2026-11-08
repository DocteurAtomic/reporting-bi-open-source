-- Clip 6.3. The definitions of the glossary, checked against the data, run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_06/03-check.sql

-- "Inscription annulée": a date of cancellation. The waiting list is another column.
select count(*) as inscriptions,
       count(dateannulation) as annulees,
       count(*) filter (where dateannulation is null) as non_annulees,
       count(*) filter (where listeattente) as en_liste_attente,
       count(*) filter (where listeattente and dateannulation is not null) as en_attente_et_annulees
  from inscription.inscription;

-- "Chiffre d'affaires" against the payments received, in 2011.
select (select sum(montantht) from inscription.facture
         where datefacture between date '2011-01-01' and date '2011-12-31') as chiffre_affaires_ht_2011,
       (select sum(montant) from inscription.suivifacture
         where datepaiement between date '2011-01-01' and date '2011-12-31') as encaissements_2011;
