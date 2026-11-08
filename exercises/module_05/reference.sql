-- check: dashboard
-- check: filter 2016-01-01~2016-12-31
-- Exercise 05: the dashboard "Exercice 05" of the planning service, with a date filter
-- connected to its three cards. check.sh gives the filter the year 2016, runs each card
-- through the dashboard (setup/verify-dashboard.sh), and each query below must give the rows
-- of one card, whatever the order of the cards and of the rows.

-- card: Sessions par année
-- 2016: one row, 366 sessions.
select date_trunc('year', datedebut)::date as annee, count(*) as sessions
  from stage.session
 where datedebut between date '2016-01-01' and date '2016-12-31'
 group by 1;

-- card: Inscriptions non annulées par session, en moyenne
-- 2016: 730 registrations not cancelled on 366 sessions, 1.99. One session (2441) has only
-- cancelled registrations: it counts as zero. Counting the cancelled ones too gives 732 / 366,
-- and leaving that session out gives 730 / 365: 2.00 both times.
select avg(n) as moyenne
  from (select s.sessionid, count(i.inscriptionid) filter (where i.dateannulation is null) as n
          from stage.session s
          left join inscription.inscription i on i.sessionid = s.sessionid
         where s.datedebut between date '2016-01-01' and date '2016-12-31'
         group by s.sessionid) x;

-- card: Les trois stages les plus programmés
-- 2016: three courses with six sessions each; the fourth has five.
select sl.titre, count(*) as sessions
  from stage.session s
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
 where s.datedebut between date '2016-01-01' and date '2016-12-31'
 group by sl.titre
 order by 2 desc
 limit 3;
