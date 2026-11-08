-- check: card
-- Reference of exercise 01: the number of contacts by title (the column titre: Mme, M.), the
-- contacts without a title included, as the row whose titre is null.
-- Expected: Mme 18761, M. 15252, no title 1076.
select titre, count(*) as nombre
  from contact.contact
 group by titre;
