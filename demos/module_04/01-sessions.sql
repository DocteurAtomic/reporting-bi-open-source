-- Clip 4.1. The check of "Sessions organisées" (a number) and of "Sessions par année, en
-- barres", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_04/01-sessions.sql
-- Expected: 3039 sessions in the table; eight years, whose counts add up to 3039.

-- The number shown by the question: every row of the table.
select count(*) as sessions from stage.session;

-- The bars: one per year of start date, and their sum.
select extract(year from datedebut) as annee, count(*) as sessions
  from stage.session
 group by annee
 order by annee;

select sum(sessions) as somme_des_barres
  from (select count(*) as sessions from stage.session group by extract(year from datedebut)) b;
