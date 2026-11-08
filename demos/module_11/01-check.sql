-- Video 11.1: the number of companies that the first page of the site, site/index.sql, shows.
-- Run as lecture_bi, the role SQLPage reads the database with:
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_11/01-check.sql
-- 179 companies; current_user says lecture_bi.
select current_user, count(*) as societes from contact.societe;
