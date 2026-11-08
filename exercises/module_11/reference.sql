-- check: page planning.sql
-- Exercise 11: the page site/planning.sql of the planning service, checked in its JSON by
-- setup/verify-page.sh: each query below must give the rows of one component of the page,
-- whatever the names of its columns and the order of its rows.

-- component: Sessions intra-entreprise
-- 1 117 sessions out of 3 039 are held within a company (intraentrerprise is true; the column
-- keeps the spelling mistake of the database). count(intraentrerprise) counts the false ones
-- too: 3 039.
select count(*) filter (where intraentrerprise) as sessions_intra
  from stage.session;

-- component: Sessions par année
-- Eight years, by the start date: 580 sessions in 2011 and 267 in 2012, none within a company;
-- then 365 or 366 a year from 2015 to 2020, of which 175 to 195 within a company. No session in
-- 2013 nor 2014. A filter on intraentrerprise before grouping loses 2011 and 2012.
select extract(year from datedebut)::int as annee,
       count(*) as sessions,
       count(*) filter (where intraentrerprise) as sessions_intra
  from stage.session
 group by 1
 order by 1;
