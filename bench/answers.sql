-- The reference answers of the bench (bench/questions.txt), one query per question, computed by
-- hand in SQL. A question with two readings or more (Q16 to Q20) gets one column per reading:
-- an answer of Metabot is right when it matches one reading and says which one.
-- Run as lecture_bi, the role Metabase reads with:
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < bench/answers.sql
\pset footer off
\echo Q01 nombre de stages
select count(*) from stage.stage;
\echo Q02 sessions qui commencent en 2015
select count(*) from stage.session where datedebut >= '2015-01-01' and datedebut < '2016-01-01';
\echo Q03 CA HT facture en 2011 (datefacture)
select sum(montantht), sum(montanthtremise) from inscription.facture where datefacture >= '2011-01-01' and datefacture < '2012-01-01';
\echo Q04 inscriptions non annulees
select count(*) from inscription.inscription where dateannulation is null;
\echo Q05 top 5 societes par inscriptions
select s.nom, count(*) from inscription.inscription i join contact.contact c using (contactid) join contact.societe s using (societeid) group by s.societeid, s.nom order by 2 desc limit 6;
\echo Q06 prix moyen des sessions de 2016
select round(avg(prix),2) from stage.session where extract(year from datedebut)=2016;
\echo Q07 contacts sans email
select count(*) filter (where email is null), count(*) filter (where email is null or trim(email)='') from contact.contact;
\echo Q08 factures sans aucun paiement
select count(*) from inscription.facture f where not exists (select 1 from inscription.suivifacture p where p.facturecd=f.facturecd);
\echo Q09 stage avec le plus de sessions
select sl.titre, count(*) from stage.session se join stage.stagelangue sl using (stageid) group by sl.stageid, sl.titre order by 2 desc limit 3;
\echo Q10 taux de presence des inscriptions non annulees
select round(100.0*count(*) filter (where present)/count(*),1), count(*) filter (where present is null) from inscription.inscription where dateannulation is null;
\echo Q11 lieu de formation avec le plus de sessions
select l.nom, count(*) from stage.session se join reference.salleformation sf using (salleformationid) join reference.lieuformation l using (lieuformationid) group by l.lieuformationid, l.nom order by 2 desc limit 3;
\echo Q12 mois de 2019 avec le plus d inscriptions creees
select to_char(datecreation,'YYYY-MM'), count(*) from inscription.inscription where datecreation >= '2019-01-01' and datecreation < '2020-01-01' group by 1 order by 2 desc limit 3;
\echo Q13 montant encaisse en 2011 (datepaiement)
select sum(montant) from inscription.suivifacture where datepaiement >= '2011-01-01' and datepaiement < '2012-01-01';
\echo Q14 contacts distincts avec au moins une inscription
select count(distinct contactid) from inscription.inscription;
\echo Q15 duree moyenne des stages en jours
select round(avg(duree),2) from stage.stage;
\echo Q16 chiffre d affaires de 2011 : hors taxes, toutes taxes, hors taxes apres remise
select sum(montantht) as ht, sum(montantttc) as ttc, sum(montanthtremise) as ht_apres_remise
  from inscription.facture where datefacture >= '2011-01-01' and datefacture < '2012-01-01';
\echo Q17 inscriptions en 2019 : creees en 2019, ou sur des sessions qui commencent en 2019
select (select count(*) from inscription.inscription
         where datecreation >= '2019-01-01' and datecreation < '2020-01-01') as creees,
       (select count(*) from inscription.inscription
         where datecreation >= '2019-01-01' and datecreation < '2020-01-01' and dateannulation is null) as creees_non_annulees,
       (select count(*) from inscription.inscription i join stage.session s using (sessionid)
         where s.datedebut >= '2019-01-01' and s.datedebut < '2020-01-01') as sessions_2019,
       (select count(*) from inscription.inscription i join stage.session s using (sessionid)
         where s.datedebut >= '2019-01-01' and s.datedebut < '2020-01-01' and i.dateannulation is null) as sessions_2019_non_annulees;
\echo Q18 taux d annulation des inscriptions
select round(100.0 * count(dateannulation) / count(*), 2) as pourcentage, count(dateannulation) as annulees, count(*) as inscriptions
  from inscription.inscription;
\echo Q19 stagiaires des sessions de 2016 (contacts distincts)
select count(distinct i.contactid) as inscrits,
       count(distinct i.contactid) filter (where i.dateannulation is null) as non_annules,
       count(distinct i.contactid) filter (where i.present) as presents,
       count(distinct i.contactid) filter (where i.dateannulation is null and not i.listeattente) as hors_annules_et_attente,
       count(distinct i.contactid) filter (where i.dateannulation is null and not i.listeattente and i.present) as dont_presents
  from inscription.inscription i join stage.session s using (sessionid)
 where s.datedebut >= '2016-01-01' and s.datedebut < '2017-01-01';
\echo Q20 remise moyenne : des inscriptions, des inscriptions qui en ont une, des factures, des societes
select (select round(avg(remise), 2) from inscription.inscription) as inscription,
       (select round(avg(remise), 2) from inscription.inscription where remise > 0) as inscription_positive,
       (select count(*) from inscription.inscription where remise > 0) as inscriptions_avec_remise,
       (select round(avg(remise), 2) from inscription.facture) as facture,
       (select round(avg(remise), 2) from contact.societe) as societe;
