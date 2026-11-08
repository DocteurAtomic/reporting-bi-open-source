# Exercice du module 3

La facturation veut compter ses factures sur la période qu'elle choisit : combien de factures,
et pour quel montant hors taxes. Elle veut le choisir dans un calendrier, comme pour les
encaissements de la vidéo 3.3, et elle veut voir 2011 à l'ouverture.

## Le travail demandé

1. Dans Metabase, ouvrez une nouvelle requête SQL sur `pachadataformation`.
2. Écrivez la requête qui rend, sur la table `inscription.facture`, deux colonnes : le nombre de
   factures, et la somme de `montantht`. Filtrez-la par un filtre de champ nommé `periode` :
   `where {{periode}}`, sans colonne ni opérateur.
3. Dans le panneau de la variable, donnez-lui le type « Filtre de champ », reliez-la à la colonne
   `datefacture` de la table `facture`, et donnez-lui pour valeur par défaut l'année 2011, du
   1er janvier au 31 décembre.
4. Vérifiez à l'écran : 6 514 factures pour 22 486 000.
5. Enregistrez la question sous le nom « Exercice 03 », dans la collection de votre choix.
6. Depuis le dossier du clone, lancez `./setup/check.sh 03`.

## Le contrôle

`check.sh` retrouve la question par son nom, l'exécute par l'API de Metabase avec une autre
période que celle de l'écran, l'année 2007, et compare ses lignes à celles de
`reference.sql`, jouée dans psql. Une question qui ignore son filtre, ou qui filtre une autre
colonne, rend les bons nombres en 2011 et de faux en 2007. Le nom des colonnes ne compte pas,
leur nombre et leur ordre comptent. Une réponse juste finit ainsi :

```text
Variable {{periode}}: 2007-01-01~2007-12-31
PASS: 1 rows, the same as the reference
Exercise 03: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 03"` | la question n'est pas enregistrée, ou elle est à la corbeille, ou son nom diffère | 2 |
| `FAIL error: {{periode}} is a text variable, and the exercise asks for a field filter` | la variable est de type texte, nombre ou date : choisissez « Filtre de champ » | 2 |
| `FAIL error: the question does not run (HTTP 400): ERROR: missing FROM-clause entry for table "facturecolumnstore"` | le filtre est relié à la colonne `datefacture` d'une autre table, `facturecolumnstore` | 2 |
| `Note: the question has no variable {{periode}}` puis `FAIL rows` | la variable n'existe pas sous ce nom, ou la période est écrite dans la requête | 3 |
| `FAIL rows` et `not expected: 321 \| ...` | le filtre est relié à `datecreation` et non à `datefacture` | 3 |
| `FAIL rows` | une autre colonne de montant, ou un autre calcul | 3 |
| `FAIL columns` | plus ou moins de deux colonnes, ou un texte à la place d'un nombre | 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

La solution est dans `solution/`, à lire après avoir cherché : `exercice-03.sql` est la
requête, `exercice-03.json` la question telle que l'API la crée, `create.sh` la recrée.

---

# Exercise of module 3

In Metabase, write a new SQL query on `pachadataformation` that returns two columns from
`inscription.facture`: the number of invoices and the sum of `montantht`, filtered by a field
filter named `periode` (`where {{periode}}`, with no column and no operator). In the variable
panel, set its type to Field filter, map it to the column `datefacture` of the table
`facture`, and give it the year 2011 as its default value (January 1 to December 31). The
screen shows 6,514 invoices for 22,486,000. Save the question as "Exercice 03" and run
`./setup/check.sh 03` from the clone. The check runs the question through the API of Metabase
with another period, the year 2007, and compares its rows with `reference.sql` run in psql: a
question that ignores its filter, or filters another column, is right for 2011 and wrong for
2007. Exit codes: 0 passed, 1 lab, 2 missing question, wrong kind of variable or a query that
fails, 3 different rows, 4 different columns. The solution is in `solution/`, to read after
trying.
