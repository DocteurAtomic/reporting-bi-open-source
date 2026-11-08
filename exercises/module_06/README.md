# Exercice du module 6

La facturation suit, pour 2011, le chiffre d'affaires, que la métrique
« Chiffre d'affaires HT » du module définit, et les encaissements, les paiements reçus. Elle
veut que les encaissements aient aussi leur définition unique.

## Le travail demandé

1. Créez une métrique (« Nouveau », « Métrique ») sur la table « Suivifacture » du schéma
   `inscription` : la somme de « Montant », sans filtre. Enregistrez-la sous le nom
   « Encaissements », avec une description, dans la collection de votre choix.
2. Créez une question sur la table « Suivifacture ». Dans « Résumer », choisissez la métrique
   « Encaissements » (rubrique des métriques), et non « Somme de ».
3. Filtrez sur l'année 2011 des paiements : du 1er janvier au 31 décembre 2011.
4. Vérifiez à l'écran : 8 846 812.
5. Enregistrez la question sous le nom « Exercice 06 ».
6. Depuis le dossier du clone, lancez `./setup/check.sh 06`.

## Le contrôle

`check.sh` retrouve la question par son nom, l'exécute par l'API de Metabase et compare sa ligne
à celle de `reference.sql`, jouée dans psql. Puis il lit la question elle-même : une de ses
agrégations doit être une métrique, et cette métrique une métrique enregistrée sous le nom
« Encaissements ». Une réponse juste finit ainsi :

```text
PASS: 1 rows, the same as the reference
PASS: uses the metric "Encaissements" (id 91)
PASS: the rows and the metric are the ones asked for
Exercise 06: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 06"` | la question n'est pas enregistrée, ou elle est à la corbeille, ou son nom diffère | 2 |
| `FAIL rows`, `not expected: 8891662` | le filtre s'applique à la date de la facture (Facture → Datefacture) : les 10 paiements reçus en 2012 pour des factures de 2011 sont comptés | 3 |
| `FAIL rows` | un autre filtre, ou pas de filtre | 3 |
| `FAIL metric: the question does not use the metric "Encaissements"` | la ligne est juste, mais la question additionne `montant` elle-même, ou la métrique a un autre nom, ou ce n'est pas une métrique | 3 |
| `FAIL columns` | plus d'une colonne, par exemple un regroupement en plus | 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

Vérifiez aussi à la main dans psql :

```sql
select count(*) as paiements, sum(montant) as encaissements
  from inscription.suivifacture
 where datepaiement between date '2011-01-01' and date '2011-12-31';
```

La solution est dans `solution/`, à lire après avoir cherché : `metric-encaissements.json` est la
métrique telle que l'API la crée, `exercice-06.json` la question, `create.sh` les recrée.

---

# Exercise of module 6

Create a metric on the table `inscription.suivifacture`: the sum of `montant`, without a
filter, saved as "Encaissements". Then create a question on the same table that picks the metric
"Encaissements" in Summarize (not a "Sum of"), filtered on the payment date from January 1 to
December 31, 2011: 8 846 812. Save it as "Exercice 06" and run `./setup/check.sh 06` from the
clone. The check runs the question through the API of Metabase, compares its row with
`reference.sql` run in psql, then reads the question to see that one of its aggregations is a
saved metric named "Encaissements". A filter on the date of the invoice instead of the date of
payment gives 8 891 662 (the 10 payments received in 2012 for invoices of 2011), and the same
sum written without the metric is refused. Exit codes: 0 passed, 1 lab, 2 missing question,
3 different rows or no metric, 4 different columns. The solution is in `solution/`, to read
after trying.
