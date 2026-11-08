-- The first page of the SQLPage site (module 11): the number of companies of the organization.
-- SQLPage runs it as lecture_bi; the JSON of the page (Accept: application/json) gives 179.
select 'big_number' as component;
select 'Companies' as title, count(*) as value from contact.societe;
