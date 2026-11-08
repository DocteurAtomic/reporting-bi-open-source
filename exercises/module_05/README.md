# Exercice du module 5

Le service du planning veut son propre tableau de bord, avec une année à choisir en haut de
l'écran et trois cartes qui la suivent toutes : combien de sessions, combien d'inscrits en
moyenne par session, et quels stages sont les plus programmés.

## Le travail demandé

1. Dans Metabase, créez trois questions sur `pachadataformation`, par l'éditeur ou en SQL :
   - le nombre de sessions par année de début (`stage.session`, `datedebut`) ;
   - le nombre moyen d'inscriptions non annulées par session (`inscription.inscription`,
     `dateannulation` vide), où une session sans inscription non annulée compte pour zéro ;
   - les trois stages qui ont le plus de sessions, avec leur titre (`stage.stagelangue`) et
     leur nombre de sessions.
2. Créez un tableau de bord nommé « Exercice 05 » et ajoutez-y les trois questions.
3. Ajoutez un filtre de date, de type « Toutes les options », et reliez-le aux trois cartes,
   sur la date de début de la session.
4. Vérifiez à l'écran avec l'année 2016, du 1er janvier au 31 décembre : 366 sessions, 1,99
   inscription en moyenne, et trois stages à six sessions.
5. Depuis le dossier du clone, lancez `./setup/check.sh 05`.

## Le contrôle

`check.sh` retrouve le tableau de bord par son nom, donne à son filtre de date l'année 2016,
exécute chaque carte par l'API, comme le navigateur, et compare ses lignes à celles des trois
requêtes de `reference.sql`, jouées dans psql. L'ordre des cartes et des lignes ne compte pas,
ni le nom des colonnes ; leur nombre et leur type comptent. Une carte non reliée au filtre est
refusée. Une réponse juste finit ainsi :

```text
PASS: 3 cards, the same as the references, all connected to the filter
Exercise 05: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no dashboard named "Exercice 05"` | le tableau de bord n'est pas enregistré, ou il est à la corbeille, ou son nom diffère | 2 |
| `FAIL error: the dashboard has no date filter` | le filtre manque, ou il n'est pas de type date | 2 |
| `FAIL error: the filter ... takes a single date` | le filtre est de type « Date unique » : choisissez « Toutes les options » | 2 |
| `FAIL card "...": not connected to the filter` | la carte n'est reliée à aucune colonne du filtre | 3 |
| `FAIL reference "Inscriptions non annulées par session, en moyenne"` et `not expected: 2` | les inscriptions annulées sont comptées, ou la session sans inscription non annulée a disparu | 3 |
| `FAIL reference "..."` | une autre carte rend d'autres lignes : vérifiez sa colonne de filtre et son calcul | 3 ou 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

La solution est dans `solution/`, à lire après avoir cherché : les trois questions telles que
l'API les crée (`*.json`, la moyenne en SQL dans `moyenne-par-session.sql`), le tableau de bord
(`exercice-05.json`) et `create.sh`, qui recrée le tout.

---

# Exercise of module 5

Build the dashboard of the planning service in Metabase, saved as "Exercice 05", with three
questions on `pachadataformation`: the number of sessions by year of `stage.session.datedebut`;
the average number of registrations that are not cancelled (`dateannulation` empty) per
session, a session without such a registration counting as zero; and the three courses with
the most sessions, with their title from `stage.stagelangue`. Add a date filter of type All
options and connect it to the three cards, on the start date of the session. With the year 2016
the screen shows 366 sessions, 1.99 registrations on average, and three courses with six
sessions each. Run `./setup/check.sh 05` from the clone: it gives the filter the year 2016, runs
each card through the dashboard as the browser does, and compares its rows with the queries of
`reference.sql` run in psql. Exit codes: 0 passed, 1 lab, 2 missing dashboard or a filter that
cannot take a year, 3 a card not connected to the filter or with other rows, 4 other columns.
The solution is in `solution/`, to read after trying.
