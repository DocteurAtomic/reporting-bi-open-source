-- Clip 1.2: what lecture_bi can do. Plays under the role Metabase uses:
--   docker compose exec db psql -U lecture_bi -d pachadataformation
-- The connection, then a count that lecture_bi may read. Read only. Expected: 179 companies.
\conninfo
select count(*) from contact.societe;
