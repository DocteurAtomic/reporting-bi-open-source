-- Clip 3.1: the revenue of each course, written in SQL in the SQL editor of Metabase, with the
-- invoices linked to no session on a line of their own. An invoice counts once per course
-- (select distinct), and once only on the line "(sans session)" (not exists). Paste it in
-- New > SQL query, on pachadataformation; it also runs as it is in psql, as lecture_bi.
-- Saved in Metabase as "Chiffre d'affaires par stage en SQL".
with facture_stage as (
    select distinct s.stageid, f.facturecd, f.montantht
      from inscription.facture f
      join inscription.inscriptionfacture fi on fi.facturecd = f.facturecd
      join inscription.inscription i on i.inscriptionid = fi.inscriptionid
      join stage.session s on s.sessionid = i.sessionid
)
select sl.titre as stage,
       count(*) as factures,
       sum(fs.montantht) as montant_ht
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
 order by montant_ht desc
;
