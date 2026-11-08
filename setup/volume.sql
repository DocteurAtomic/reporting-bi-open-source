-- Module 8. A fact table made up for the course, in its own schema entrepot of
-- pachadataformation: the visits of the online catalogue of the training centre, one row per
-- visit of the page of a course, from 2015 to 2020. pachadataformation has no table big enough
-- to make a dashboard slow (its biggest table has 300 000 rows); this one has 5 000 000.
-- Nothing in the tables of the database is changed: entrepot is the only schema the course
-- writes in. The values come from random() after setseed(): the same seed gives the same rows,
-- and the same totals, on every lab running PostgreSQL 18.
-- Run by ./setup/volume.sh, as postgres; lecture_bi reads the schema and the table through the
-- default privileges that ./setup/install.sh gave it (usage, select and references).
\set ON_ERROR_STOP on
create schema if not exists entrepot;
comment on schema entrepot is 'Data made up for module 8 of the course: not part of pachadataformation.';

create table entrepot.visite (
    jour      date not null,
    visiteur  integer not null,
    stageid   integer not null,
    societeid integer,
    duree     integer not null
);
comment on table entrepot.visite is 'Visits of the pages of the online catalogue, one row per visit, made up by setup/volume.sql (seed 0.42).';
comment on column entrepot.visite.jour is 'Day of the visit, from 2015-01-01 to 2020-12-31.';
comment on column entrepot.visite.visiteur is 'Anonymous identifier of the visitor (a browser), from 1 to 1 000 000.';
comment on column entrepot.visite.stageid is 'The course whose page was visited (stage.stage).';
comment on column entrepot.visite.societeid is 'The company of the visitor when known (contact.societe), empty otherwise.';
comment on column entrepot.visite.duree is 'Time spent on the page, in seconds.';

-- random() runs in this backend only (it is parallel restricted), row after row, so the seed
-- fixes every value. More visits in the later years (the square root), the first courses
-- visited more than the last ones (the square), a known company for three visits in ten.
\o /dev/null
select setseed(0.42);
\o
insert into entrepot.visite (jour, visiteur, stageid, societeid, duree)
select date '2015-01-01' + floor(2192 * sqrt(random()))::int,
       1 + floor(1000000 * random())::int,
       1 + floor(168 * random() ^ 2)::int,
       case when random() < 0.3 then 1 + floor(179 * random())::int end,
       10 + floor(600 * random())::int
  from generate_series(1, 5000000);
analyze entrepot.visite;
