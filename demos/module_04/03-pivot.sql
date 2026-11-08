-- Clip 4.3. The check of the pivot table "Inscriptions par stage et par année", run as
-- lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_04/03-pivot.sql
-- Expected: twelve stages, because three are tied at the tenth place (195); the row of
-- "SQL Server 2005 Expertise" adds up to 267; 2657 registrations in all.

-- The ranking of the stages by registrations not cancelled, around the tenth place.
select sl.titre, count(*) as inscriptions,
       rank() over (order by count(*) desc) as rang
  from inscription.inscription i
  join stage.session s on s.sessionid = i.sessionid
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
 where i.dateannulation is null
 group by sl.titre
 order by inscriptions desc
 limit 14;

-- One row of the pivot table, year by year, and its total.
select extract(year from s.datedebut) as annee, count(*) as inscriptions
  from inscription.inscription i
  join stage.session s on s.sessionid = i.sessionid
  join stage.stagelangue sl on sl.stageid = s.stageid and sl.languecd = s.languecd
 where i.dateannulation is null and sl.titre = 'SQL Server 2005 Expertise'
 group by rollup (annee)
 order by annee nulls last;

-- The grand total of the pivot table: the rows of its source question, the registrations not
-- cancelled of the twelve stages.
with par_stage as (
    select s.stageid, count(*) as inscriptions
      from inscription.inscription i
      join stage.session s on s.sessionid = i.sessionid
     where i.dateannulation is null
     group by s.stageid
     order by inscriptions desc
     fetch first 10 rows with ties
)
select count(*) as stages, sum(inscriptions) as inscriptions from par_stage;
