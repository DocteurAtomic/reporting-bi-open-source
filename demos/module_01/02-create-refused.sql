-- Clip 1.2: lecture_bi cannot write. Plays under lecture_bi, like 02-lab-check.sql.
-- Fails on purpose with: ERROR:  permission denied for schema public
-- (psql then exits with code 3 when it runs with ON_ERROR_STOP). Nothing is created.
create table essai (id int);
