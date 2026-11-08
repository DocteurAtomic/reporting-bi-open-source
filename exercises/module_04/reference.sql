-- check: card
-- check: display line
-- check: setting line.missing zero interpolate
-- check: setting graph.x_axis.scale timeseries timeseries
-- Exercise 04: the number of invoices by year of invoice, from 2005 to 2011, in a line chart
-- whose missing values are shown as zero. The query returns the four years that have invoices
-- (2005 155, 2006 190, 2007 206, 2011 6514): Metabase adds 2008, 2009 and 2010 when it draws
-- the line, so the check also reads the kind of chart and two settings of the card.
select date_trunc('year', datefacture)::date as annee, count(*) as factures
  from inscription.facture
 where datefacture between date '2005-01-01' and date '2011-12-31'
 group by annee;
