-- Clip 4.2. The years a chart of the sessions by year must show, run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_04/02-missing-years.sql
-- Expected: ten years from 2011 to 2020, two of them (2013 and 2014) with no session.

-- Every year from the first to the last, the years without a session included, at zero.
select a.annee, count(s.sessionid) as sessions
  from generate_series(2011, 2020) as a(annee)
  left join stage.session s on extract(year from s.datedebut) = a.annee
 group by a.annee
 order by a.annee;
