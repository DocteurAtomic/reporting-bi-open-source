-- check: answers work/answer09.csv
-- The accepted answers of the ten questions of exercises/module_09/questions.txt, computed by
-- hand in SQL: one row per reading of a question (question, reading, value). In
-- work/answer09.csv, an answer marked "juste" must equal one of the values of its question, at
-- the precision written; an answer marked "faux" must equal none of them.
select 'E01' as question, 'toutes les sociétés' as lecture, count(*)::numeric as valeur
  from contact.societe
union all
select 'E01', 'sociétés dont un contact a une inscription', count(distinct c.societeid)
  from inscription.inscription i join contact.contact c using (contactid)
union all
select 'E02', 'date de facture en 2010', count(*)
  from inscription.facture where datefacture >= date '2010-01-01' and datefacture < date '2011-01-01'
union all
select 'E03', 'hors taxes', round(avg(montantht), 2)
  from inscription.facture where datefacture >= date '2011-01-01' and datefacture < date '2012-01-01'
union all
select 'E03', 'toutes taxes comprises', round(avg(montantttc), 2)
  from inscription.facture where datefacture >= date '2011-01-01' and datefacture < date '2012-01-01'
union all
select 'E04', 'toutes les sessions', count(*)
  from stage.session where datedebut >= date '2018-01-01' and datedebut < date '2019-01-01'
union all
select 'E04', 'sans le statut A', count(*) filter (where trim(statut) is distinct from 'A')
  from stage.session where datedebut >= date '2018-01-01' and datedebut < date '2019-01-01'
union all
select 'E05', 'contacts sans société', count(*) filter (where societeid is null)
  from contact.contact
union all
select 'E06', 'toutes les inscriptions en attente', count(*) filter (where listeattente)
  from inscription.inscription
union all
select 'E06', 'inscriptions en attente non annulées', count(*) filter (where listeattente and dateannulation is null)
  from inscription.inscription
union all
select 'E07', 'factures de 2011 relancées au moins une fois', count(*) filter (where relance > 0)
  from inscription.facture where datefacture >= date '2011-01-01' and datefacture < date '2012-01-01'
union all
select 'E08', 'stages sans aucune session', count(*)
  from stage.stage s where not exists (select from stage.session se where se.stageid = s.stageid)
union all
select 'E09', 'inscriptions présentes', count(*) filter (where i.present)
  from inscription.inscription i join stage.session s using (sessionid)
 where s.datedebut >= date '2015-01-01' and s.datedebut < date '2016-01-01'
union all
select 'E09', 'personnes distinctes présentes', count(distinct i.contactid) filter (where i.present)
  from inscription.inscription i join stage.session s using (sessionid)
 where s.datedebut >= date '2015-01-01' and s.datedebut < date '2016-01-01'
union all
select 'E10', 'formateurs distincts des sessions de 2016', count(distinct formateurid)
  from stage.session where datedebut >= date '2016-01-01' and datedebut < date '2017-01-01'
