-- The page written by Claude Code in video 11.3 (./demos/module_11/03-claude.sh, measured on
-- 8 November 2026), as it wrote it: 11 turns, 74 seconds. Kept to read its diff with the page
-- reviewed in video 11.4, site/facturation-claude.sql. Its comments are the agent's, in French.
-- Page intranet facturation (SQLPage 0.47, PostgreSQL 18)
select 'shell' as component, 'Facturation' as title, 'fr' as language;

-- 1. Nombre de factures sans aucun paiement (aucune ligne dans suivifacture)
select 'big_number' as component;
select
    'Factures sans aucun paiement' as title,
    count(*) as value,
    'red' as color
from inscription.facture f
where not exists (
    select 1 from inscription.suivifacture s where s.facturecd = f.facturecd
);

-- 2. Ces factures impayées, par année de facture
--    (les factures sans date de facture ne peuvent pas être rangées par année : exclues du graphique)
select 'chart' as component,
    'Factures sans paiement par année de facture' as title,
    'bar' as type,
    'Année' as xtitle,
    'Nombre de factures' as ytitle;
select
    extract(year from f.datefacture)::int::text as x,
    count(*) as y
from inscription.facture f
where f.datefacture is not null
  and not exists (
    select 1 from inscription.suivifacture s where s.facturecd = f.facturecd
  )
group by 1
order by 1;

-- 3. Dix sociétés les plus facturées hors taxes, toutes années confondues.
--    Société d'une facture : facture -> inscriptionfacture -> inscription -> contact -> societe.
--    On dédoublonne (facture, société) pour ne pas compter deux fois une facture
--    qui couvre plusieurs inscriptions de la même société.
select 'table' as component, 'Dix sociétés les plus facturées (HT)' as title,
    'Total HT' as money, 1 as freeze_columns;
select
    s.nom as "Société",
    sum(f.montantht) as "Total HT",
    count(*) as "Factures"
from (
    select distinct i.facturecd, c.societeid
    from inscription.inscriptionfacture i
    join inscription.inscription x on x.inscriptionid = i.inscriptionid
    join contact.contact c on c.contactid = x.contactid
    where c.societeid is not null
) l
join inscription.facture f on f.facturecd = l.facturecd
join contact.societe s on s.societeid = l.societeid
group by s.societeid, s.nom
order by sum(f.montantht) desc, s.nom
limit 10;
