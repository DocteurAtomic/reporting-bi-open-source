-- Moves every email address of the restored database to a reserved .example domain
-- (RFC 2606): the people are fictitious, the original domains are not.
-- Run once by install.sh, right after the restore.
update contact.contact
   set email  = regexp_replace(email,  '@([^.@]+).*$', '@\1.example'),
       email2 = regexp_replace(email2, '@([^.@]+).*$', '@\1.example')
 where email !~ '\.example$' or email2 !~ '\.example$';
update contact.prospectus
   set email = regexp_replace(email, '@([^.@]+).*$', '@\1.example')
 where email !~ '\.example$';
update formateur.societeformateur
   set emailcontact = regexp_replace(emailcontact, '@([^.@]+).*$', '@\1.example')
 where emailcontact !~ '\.example$';
update reference.lieuformation
   set emailcontact = regexp_replace(emailcontact, '@([^.@]+).*$', '@\1.example')
 where emailcontact !~ '\.example$';
