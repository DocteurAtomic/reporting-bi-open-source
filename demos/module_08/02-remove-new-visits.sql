-- Clip 8.2. Takes away the visits of 02-new-visits.sql (visitors above 1 000 000): the fact
-- table is back to the 5 000 000 rows of ./setup/volume.sh. Run as postgres:
-- docker compose exec -T db psql -U postgres -d pachadataformation < demos/module_08/02-remove-new-visits.sql
delete from entrepot.visite where visiteur > 1000000;
select count(*) as visites from entrepot.visite;
