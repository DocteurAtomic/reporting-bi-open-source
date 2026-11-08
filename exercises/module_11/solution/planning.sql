-- A solution of exercise 11: the page of the planning service. Copy it to site/planning.sql
-- (./exercises/module_11/solution/create.sh), then open http://localhost:8080/planning.sql.

select 'shell' as component, 'Planning' as title, 'fr' as language;

select 'big_number' as component;
select 'Sessions intra-entreprise' as title,
       count(*) filter (where intraentrerprise) as value,
       'sur ' || count(*) || ' sessions' as description
  from stage.session;

-- Every year that has sessions, the years without any session within a company included:
-- the filter is in the count, not in a where clause.
select 'title' as component, 'Sessions par année de début' as contents, 2 as level;
select 'table' as component;
select extract(year from datedebut)::int as "Année",
       count(*) as "Sessions",
       count(*) filter (where intraentrerprise) as "Intra-entreprise"
  from stage.session
 group by 1
 order by 1;
