-- check: card
-- check: source materialized view entrepot
-- Exercise 08: the visits of the catalogue and the time spent on its pages, by year, read from
-- a materialized view of the schema entrepot and not from the fact table entrepot.visite. The
-- check runs the question "Exercice 08", compares its six rows with this query (computed here
-- on the fact table), then reads the question to see that its source is a materialized view of
-- entrepot. The same rows read from entrepot.visite give 3.
select cast(date_trunc('year', jour) as date) as annee,
       count(*) as visites,
       sum(duree) as duree
  from entrepot.visite
 group by 1;
