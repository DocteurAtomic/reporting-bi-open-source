-- Clip 10.2. The first question asked to Claude Code through the MCP server: the number of
-- courses in the catalog, and those without a cancellation date, the figure it gave as well.
-- Read only, as lecture_bi:
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_10/02-check.sql
select count(*) as stages,
       count(*) filter (where dateannulation is null) as stages_sans_annulation
  from stage.stage;
