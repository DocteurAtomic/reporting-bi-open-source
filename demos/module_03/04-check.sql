-- Clip 3.4, the check in psql: the questions built on a saved SQL question.
--   docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_03/04-check.sql
-- Read only.

-- 1. "Total du chiffre d'affaires par stage", built on "Chiffre d'affaires par stage en SQL":
--    the sum of its two columns over the 169 rows of the source.
with source as (
    with facture_stage as (
        select distinct s.stageid, f.facturecd, f.montantht
          from inscription.facture f
          join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
          join inscription.inscription i on i.inscriptionid = fi.inscriptionid
          join stage.session s on s.sessionid = i.sessionid
    )
    select sl.titre as stage, count(*) as factures, sum(fs.montantht) as montant_ht
      from facture_stage fs
      join stage.stagelangue sl on sl.stageid = fs.stageid
     group by sl.stageid, sl.titre
    union all
    select '(sans session)', count(*), sum(f.montantht)
      from inscription.facture f
     where not exists (
            select
              from inscription.inscriptionfacture fi
              join inscription.inscription i on i.inscriptionid = fi.inscriptionid
              join stage.session s on s.sessionid = i.sessionid
             where fi.facturecd = f.facturecd)
)
select count(*) as lignes, sum(factures) as factures, sum(montant_ht) as montant_ht
  from source;

-- 2. "Encaissements depuis la période", built on "Encaissements par période": the field filter
--    of the source gets no value, so the derived question adds up every payment.
select sum(montant) as encaisse, count(distinct date_trunc('month', datepaiement)) as mois
  from inscription.suivifacture;
