-- Clip 4.4. The check of the pie chart "Factures de 2011 par mois, en camembert", run as
-- lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_04/04-pie.sql
-- Expected: eleven months, no invoice in December; the slices add up to 6514, the total shown
-- in the middle of the chart.

select extract(month from datefacture) as mois, count(*) as factures,
       round(100.0 * count(*) / sum(count(*)) over (), 1) as pourcentage
  from inscription.facture
 where datefacture between date '2011-01-01' and date '2011-12-31'
 group by mois
 order by mois;

select count(*) as factures_2011
  from inscription.facture
 where datefacture between date '2011-01-01' and date '2011-12-31';
