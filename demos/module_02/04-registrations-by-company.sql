-- Clip 2.4. The check of "Inscriptions par société", run as lecture_bi:
-- docker compose exec -T db psql -U lecture_bi -d pachadataformation < demos/module_02/04-registrations-by-company.sql

-- The empty row of the query builder: left joins, no company.
select count(*) as sans_societe_jointure_externe
  from inscription.inscription i
  left join contact.contact c on c.contactid = i.contactid
 where c.societeid is null;

-- With an inner join on contact: the registrations whose contact has no company.
select count(*) as contact_sans_societe
  from inscription.inscription i
  join contact.contact c on c.contactid = i.contactid
 where c.societeid is null;

-- The registrations without a contact.
select count(*) as sans_contact from inscription.inscription where contactid is null;

-- All the registrations: the sum of the rows of the question.
select count(*) as inscriptions from inscription.inscription;

-- One row checked: the first company.
select so.nom, count(*) as inscriptions
  from inscription.inscription i
  join contact.contact c on c.contactid = i.contactid
  join contact.societe so on so.societeid = c.societeid
 group by so.nom
 order by inscriptions desc
 limit 1;
