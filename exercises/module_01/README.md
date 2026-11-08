# Exercice du module 1

Le service commercial veut savoir à qui il écrit : combien de contacts la base compte pour
chaque civilité, Madame, Monsieur, et ceux dont la civilité n'est pas renseignée.

## Le travail demandé

1. Montez le labo (`./setup/install.sh`), faites le premier lancement de Metabase, connectez
   `pachadataformation` sous `lecture_bi`, supprimez la base d'exemple et créez la clé d'API
   (`./setup/api-key.sh`), comme dans les vidéos 1.2 à 1.4. `./setup/check.sh 00` doit rendre
   `PASS`.
2. Dans l'éditeur de questions de Metabase, construisez une question sur la seule table
   « Contact » du schéma `contact` : le nombre de lignes par « Titre », la colonne de la
   civilité (`titre` dans la base). Gardez la ligne des contacts sans civilité.
3. Enregistrez-la sous le nom « Exercice 01 », dans « Nos analyses ».
4. Lancez `./setup/check.sh 01` depuis le clone.

Le contrôle retrouve la question par son nom avec la clé d'API, l'exécute, et compare ses
lignes à celles de `reference.sql`, jouée dans psql. L'ordre des lignes n'est pas contrôlé. Il
finit par `PASS` et le code 0 si la réponse est juste, `FAIL missing` et le code 2 si la
question n'existe pas, `FAIL rows` et le code 3 si les lignes diffèrent.

Vérifiez aussi à la main : la somme des lignes de votre question doit égaler le nombre de
contacts, `select count(*) from contact.contact;`.

La solution est dans `solution/`, à lire après avoir cherché : `exercice-01.json` est la
définition de la question, et `create.sh` la crée par l'API.

---

# Exercise of module 1

The sales team wants to know whom it writes to: how many contacts the database holds for each
title (Mme, M.), and how many have no title. Set up the lab, connect `pachadataformation` as
`lecture_bi` in Metabase, remove the sample database and create the API key
(`./setup/api-key.sh`), as in videos 1.2 to 1.4; `./setup/check.sh 00` must pass. Then build,
in the query builder and on the table `contact.contact` only, the count of rows by `titre`
(shown as "Titre"), keeping the row of the contacts without a title. Save it as "Exercice 01"
and run `./setup/check.sh 01`: it finds the question with the API key, runs it and compares its
rows with `reference.sql` (order ignored). Check by hand that the rows add up to
`select count(*) from contact.contact;`. The solution is in `solution/`: `exercice-01.json`
defines the question, `create.sh` creates it through the API.
