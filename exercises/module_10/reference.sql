-- check: card
-- Exercise 10: for each company, the registrations that are neither cancelled nor on the
-- waiting list, on the sessions that start in 2019. The registrations of contacts without a
-- company are left out (they are not a company). 85 companies, 250 registrations.
-- The question is made by Claude Code through the MCP server; this reference is written before.
select so.nom as societe, count(*) as inscriptions
  from inscription.inscription i
  join stage.session s on s.sessionid = i.sessionid
  join contact.contact c on c.contactid = i.contactid
  join contact.societe so on so.societeid = c.societeid
 where s.datedebut >= date '2019-01-01' and s.datedebut < date '2020-01-01'
   and i.dateannulation is null
   and not i.listeattente
 group by so.societeid, so.nom;
