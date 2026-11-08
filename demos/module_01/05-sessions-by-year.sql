-- Clip 1.5: the check of the question "Sessions par année" built in Metabase. The number of
-- sessions by year of their start date, under lecture_bi. Read only.
-- Expected: eight rows, 2011 580, 2012 267, then 365 or 366 a year from 2015 to 2020;
-- no row for 2013 and 2014, which have no session.
select extract(year from datedebut) as annee, count(*) as sessions
  from stage.session
 group by annee
 order by annee;
