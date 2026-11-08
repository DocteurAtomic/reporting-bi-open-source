-- Clip 8.2. A thousand visits arrive in the fact table, on December 31, 2020, from a thousand
-- new visitors (identifiers above 1 000 000, which ./setup/volume.sh never draws), so that the
-- card by month changes: 140 648 visits and 131 418 visitors in December 2020 instead of
-- 139 648 and 130 418. Run as postgres, the only role that writes in entrepot:
-- docker compose exec -T db psql -U postgres -d pachadataformation < demos/module_08/02-new-visits.sql
-- 02-remove-new-visits.sql takes them away.
insert into entrepot.visite (jour, visiteur, stageid, societeid, duree)
select date '2020-12-31', 1000000 + n, 1, null, 60
  from generate_series(1, 1000) n;
select count(*) as visites_decembre_2020, count(distinct visiteur) as visiteurs
  from entrepot.visite
 where jour between date '2020-12-01' and date '2020-12-31';
