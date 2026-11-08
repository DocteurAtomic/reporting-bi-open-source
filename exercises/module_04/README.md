# Exercice du module 4

La direction veut voir le nombre de factures émises chaque année, de 2005 à 2011, sur une
courbe. Elle veut voir aussi les années où l'organisme n'a émis aucune facture, à zéro, et non
une courbe qui monte en douceur de 2007 à 2011.

## Le travail demandé

1. Dans l'éditeur de questions de Metabase, partez de la table « Facture » du schéma
   `inscription`.
2. Filtrez sur « Datefacture », du 1er janvier 2005 au 31 décembre 2011.
3. Résumez par le nombre de lignes, regroupé par « Datefacture », à l'année.
4. Affichez le résultat en courbe (« Courbe »). Gardez l'axe X en série temporelle, l'échelle
   que Metabase choisit pour une date.
5. Dans les réglages du graphique, ouvrez les options de la série et choisissez
   « Remplacer les valeurs manquantes par » : « Zéro ».
6. Vérifiez à l'écran que la courbe tombe à zéro en 2008, 2009 et 2010.
7. Enregistrez la question sous le nom « Exercice 04 », dans la collection de votre choix.
8. Depuis le dossier du clone, lancez `./setup/check.sh 04`.

## Le contrôle

`check.sh` retrouve la question par son nom, l'exécute par l'API de Metabase et compare ses
lignes à celles de `reference.sql`, jouée dans psql. Les années à zéro n'y sont pas : Metabase
ne les ajoute qu'en dessinant la courbe, et l'API rend quatre lignes, 2005, 2006, 2007 et 2011.
Le script lit donc aussi la question elle-même : le type de graphique (`display`) et deux
réglages (`visualization_settings`), le remplacement des valeurs manquantes et l'échelle de
l'axe X. Une réponse juste finit ainsi :

```text
PASS: 4 rows, the same as the reference
PASS: drawn as line
PASS: line.missing is zero
PASS: graph.x_axis.scale is timeseries
PASS: the rows, the chart and its settings are the ones asked for
Exercise 04: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 04"` | la question n'est pas enregistrée, ou elle est à la corbeille, ou son nom diffère | 2 |
| `FAIL rows` et `not expected: 2000-01-01 ...` | le filtre ne commence pas en 2005, ou il manque | 3 |
| `FAIL display: the question is drawn as bar` | des barres, ou une aire : le remplacement par zéro ne vaut que pour une courbe ou une aire, et la demande est une courbe | 3 |
| `FAIL display: the setting line.missing is interpolate` | le réglage n'a pas été changé : la courbe relie 2007 à 2011 | 3 |
| `FAIL display: the setting line.missing is none` | « Rien » : la courbe s'interrompt au lieu de tomber à zéro | 3 |
| `FAIL display: the setting graph.x_axis.scale is ordinal` | l'axe X ordinal place 2011 juste après 2007, sans 2008 ni 2010 | 3 |
| `FAIL columns` | plus ou moins de deux colonnes, ou un texte à la place d'un nombre | 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

Vérifiez aussi à la main que les années sans facture le sont dans la base :

```sql
select a.annee, count(f.facturecd) as factures
  from generate_series(2005, 2011) as a(annee)
  left join inscription.facture f on extract(year from f.datefacture) = a.annee
 group by a.annee
 order by a.annee;
```

La solution est dans `solution/`, à lire après avoir cherché : `exercice-04.json` est la
question telle que l'API la crée, `create.sh` la recrée.

---

# Exercise of module 4

In the query builder of Metabase, start from the table `inscription.facture`, filter
`datefacture` from January 1, 2005 to December 31, 2011, and count the rows by `datefacture`
grouped by year. Show it as a line chart, keep the x-axis scale on Timeseries, and in the
options of the series set "Replace missing values with" to "Zero": the line drops to zero in
2008, 2009 and 2010, the years without an invoice. Save the question as "Exercice 04" and run
`./setup/check.sh 04` from the clone. The API returns only the four years that have invoices
(2005, 2006, 2007, 2011), since Metabase adds the missing years when it draws the line, so the
check compares the rows with `reference.sql` run in psql and also reads the kind of chart
(`display`: line) and two of its settings (`line.missing`: zero, `graph.x_axis.scale`:
timeseries). Exit codes: 0 passed, 1 lab, 2 missing question, 3 different rows or a different
chart or setting, 4 different columns. The solution is in `solution/`, to read after trying.
