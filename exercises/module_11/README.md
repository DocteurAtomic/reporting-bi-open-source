# Exercice du module 11

Le planning veut sa page sur l'intranet, à côté de celle de la facturation : combien de sessions
sont réservées à une société cliente (sessions intra-entreprise), et la même chose
année par année.

## Le travail demandé

1. Écrivez la page `site/planning.sql`, à la main ou en la faisant écrire par Claude Code
   (`demos/module_11/03-claude.sh` montre comment lui donner des droits limités).
2. Un composant `big_number` : le nombre de sessions intra-entreprise, celles dont la colonne
   `intraentrerprise` de `stage.session` vaut vrai (la faute d'orthographe est dans la base).
3. Un composant `table` ou `chart` : pour chaque année de début de session (`datedebut`),
   le nombre de sessions et le nombre de sessions intra-entreprise. Une ligne par année qui a des
   sessions, même quand aucune n'est intra-entreprise. L'année est un nombre entier.
4. Laissez les nombres bruts, sans `to_char` : la page en JSON doit les donner comme des nombres.
5. Vérifiez à l'écran, sur `http://localhost:8080/planning.sql` : 1 117 sessions
   intra-entreprise, et huit années, de 2011 à 2020 sans 2013 ni 2014.
6. SQLPage doit tourner (`docker compose --profile code up -d sqlpage`). Depuis le dossier du
   clone, lancez :

```bash
./setup/check.sh 11
```

## Le contrôle

`check.sh` demande la page à SQLPage avec l'en-tête `Accept: application/json`, puis cherche,
pour chaque requête de `reference.sql`, le composant de la page qui rend les mêmes lignes. Les
noms de vos colonnes et l'ordre de vos lignes sont libres : une colonne de la référence
correspond à la clé de vos lignes qui contient ses valeurs. Metabase n'intervient pas. Une
réponse juste finit ainsi :

```text
PASS reference "Sessions intra-entreprise": component 2 (big_number), 1 rows, the same as the reference (keys value)
PASS reference "Sessions par année": component 4 (table), 8 rows, the same as the reference (keys Année, Sessions, Intra-entreprise)
PASS: 2 components, the same as the references
Exercise 11: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: SQLPage answers 404 for /planning.sql` | pas de fichier `site/planning.sql`, ou un autre nom | 2 |
| `FAIL error: a query of the page fails` | une requête de la page échoue ; le message de PostgreSQL suit | 2 |
| `FAIL reference "Sessions intra-entreprise"`, `expected values: 1117` | `count(intraentrerprise)` compte aussi les sessions à `false` : 3 039 | 3 |
| `FAIL reference "Sessions par année"`, `6 rows in the component, 8 in the reference` | un `where intraentrerprise` avant le regroupement fait disparaître 2011 et 2012, qui n'ont aucune session intra-entreprise | 3 |
| `FAIL columns: no key of the rows holds numbers` | un nombre mis en forme par `to_char` (`1,117`) devient du texte | 4 |
| `FAIL lab` | le conteneur PostgreSQL ou SQLPage est arrêté, ou SQLPage ne répond pas | 1 |

Vérifiez aussi à la main dans psql, sous le rôle de SQLPage
(`docker compose exec db psql -U lecture_bi -d pachadataformation`) :

```sql
select count(*) as sessions, count(*) filter (where intraentrerprise) as intra
  from stage.session;
```

La solution est dans `solution/`, à lire après avoir cherché : `planning.sql` est la page,
`create.sh` la copie dans `site/` (il garde votre propre `site/planning.sql`, sauf avec
`--force`).

---

# Exercise of module 11

Write the page `site/planning.sql` of the planning service, by hand or with Claude Code: a
`big_number` component with the number of sessions reserved for one client company (`intraentrerprise` is
true in `stage.session`; the spelling mistake is in the database), 1 117; and a `table` or
`chart` component with, for each year of `datedebut`, the number of sessions and the number of
sessions within a company, one row per year that has sessions, even when none is within a
company (eight years, 2011 to 2020 without 2013 and 2014). Keep the numbers raw, without
`to_char`. With SQLPage running (`docker compose --profile code up -d sqlpage`), run
`./setup/check.sh 11` from the clone. The check asks SQLPage for the page in JSON
(`Accept: application/json`) and looks, for each query of `reference.sql`, for the component of
the page that gives the same rows, whatever the names of its columns and the order of its rows;
Metabase is not involved. `count(intraentrerprise)` gives 3 039 instead of 1 117, a
`where intraentrerprise` before grouping loses 2011 and 2012, and a number formatted with
`to_char` becomes text. Exit codes: 0 passed, 1 lab, 2 missing page or failing query,
3 different rows, 4 text instead of numbers. The solution is in `solution/`, to read after
trying.
