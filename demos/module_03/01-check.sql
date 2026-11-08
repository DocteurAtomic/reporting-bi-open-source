-- Clip 3.1, the check in psql: the lines of the question add up to more than the invoices,
-- and the difference is the invoices that cover the registrations of several courses.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_03/01-check.sql
-- Read only.

-- 1. The total of the invoices table: each invoice once.
select count(*) as factures, sum(montantht) as montant_ht
  from inscription.facture;

-- 2. The invoices that cover the registrations of more than one course, and what they add
--    to the sum of the course lines (counted once for each extra course).
with facture_stage as (
    select distinct s.stageid, f.facturecd, f.montantht
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
)
select count(*) as factures_multi_stages,
       sum(montantht * (nb_stages - 1)) as compte_en_trop
  from (select facturecd, montantht, count(*) as nb_stages
          from facture_stage
         group by facturecd, montantht
        having count(*) > 1) m;

-- 3. The reconciliation: the sum of the lines of the question (the courses, then the line
--    "(sans session)"), minus what is counted more than once, gives back the total of 1.
with facture_stage as (
    select distinct s.stageid, f.facturecd, f.montantht
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
),
lignes as (
    select (select sum(montantht) from facture_stage) as stages,
           (select sum(f.montantht)
              from inscription.facture f
             where not exists (select from facture_stage fs where fs.facturecd = f.facturecd)) as sans_session
),
en_trop as (
    select sum(montantht * (nb_stages - 1)) as montant
      from (select facturecd, montantht, count(*) as nb_stages
              from facture_stage
             group by facturecd, montantht) m
)
select l.stages, l.sans_session, l.stages + l.sans_session as total_des_lignes,
       t.montant as compte_en_trop,
       l.stages + l.sans_session - t.montant as total_des_factures
  from lignes l, en_trop t;
