-- "Planning, inscriptions par session": the average number of registrations that are not
-- cancelled, per session, the sessions without one counted as zero. The field filter
-- {{annee}} is mapped to Session > Datedebut, with the table alias s.datedebut.
select avg(n) as moyenne
  from (select s.sessionid,
               count(i.inscriptionid) filter (where i.dateannulation is null) as n
          from stage.session s
          left join inscription.inscription i on i.sessionid = s.sessionid
         where {{annee}}
         group by s.sessionid) x
