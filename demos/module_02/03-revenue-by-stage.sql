-- Clip 2.3. The check of "Chiffre d'affaires par stage", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_02/03-revenue-by-stage.sql

-- The total invoiced, from the table of invoices.
select count(*) as factures, sum(montantht) as montant_ht from inscription.facture;

-- Each invoice once per stage it covers: the sum of the stages.
with facture_stage as (
    select distinct f.facturecd, f.montantht, s.stageid
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
)
select count(*) as paires, count(distinct facturecd) as factures, sum(montantht) as montant_ht
  from facture_stage;

-- The invoices that cover registrations of more than one stage: counted for each.
select count(*) as factures_plusieurs_stages
  from (select fi.facturecd
          from inscription.inscriptionfacture fi
          join inscription.inscription i on i.inscriptionid = fi.inscriptionid
          join stage.session s on s.sessionid = i.sessionid
         group by fi.facturecd
        having count(distinct s.stageid) > 1) x;

-- What the invoices of several stages add to the sum of the stages: each one counts once
-- more for every stage after the first.
with facture_stage as (
    select distinct f.facturecd, f.montantht, s.stageid
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
), par_facture as (
    select facturecd, montantht, count(*) as stages from facture_stage group by facturecd, montantht
)
select sum((stages - 1) * montantht) as compte_en_plus, max(stages) as stages_au_plus
  from par_facture;

-- The invoices that reach no session: counted for no stage.
select count(*) as factures_sans_session, sum(f.montantht) as montant_ht
  from inscription.facture f
 where not exists (select
                     from inscription.inscriptionfacture fi
                     join inscription.inscription i on i.inscriptionid = fi.inscriptionid
                     join stage.session s on s.sessionid = i.sessionid
                    where fi.facturecd = f.facturecd);

-- One row checked: the first stage of the question.
with facture_stage as (
    select distinct f.facturecd, f.montantht, s.stageid, s.languecd
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
)
select sl.titre, count(*) as factures, sum(fs.montantht) as montant_ht
  from facture_stage fs
  join stage.stagelangue sl on sl.stageid = fs.stageid and sl.languecd = fs.languecd
 where sl.titre = 'MySQL 4.0 Découverte'
 group by sl.titre;
