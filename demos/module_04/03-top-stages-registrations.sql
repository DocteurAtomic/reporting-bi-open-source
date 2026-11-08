-- the registrations not cancelled of the ten most followed stages, ties at the tenth place included
with par_stage as (
    select s.stageid, count(*) as inscriptions
      from inscription.inscription i
      join stage.session s on s.sessionid = i.sessionid
     where i.dateannulation is null
     group by s.stageid
     order by inscriptions desc
     fetch first 10 rows with ties
)
select sl.titre, s.datedebut, i.inscriptionid
  from inscription.inscription i
  join stage.session s on s.sessionid = i.sessionid
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
  join par_stage p on p.stageid = s.stageid
 where i.dateannulation is null
