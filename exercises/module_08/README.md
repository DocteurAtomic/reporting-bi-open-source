# Exercice du module 8

La direction suit les visites du catalogue en ligne et le temps passé sur ses pages, par année.
Lue dans la table de faits `entrepot.visite`, la question met plusieurs secondes à répondre. Elle
veut la même réponse lue dans une vue matérialisée, calculée une fois.

## Le travail demandé

1. Si ce n'est pas fait, créez la table de faits : `./setup/volume.sh`.
2. Dans psql, sous `postgres` (le seul rôle qui écrit dans `entrepot`), créez dans le schéma
   `entrepot` une vue matérialisée qui compte les visites et additionne `duree` par mois et par
   stage, à partir de `entrepot.visite`. Le nom est libre.
3. Dans Metabase, synchronisez la base (« Administration », « Bases de données »,
   `pachadataformation`, « Synchroniser le schéma de la base maintenant ») pour qu'elle voie la
   vue.
4. Créez une question sur la vue, dans l'éditeur ou en SQL : par année, la somme des visites et
   la somme des durées. Trois colonnes, six lignes, de 2015 à 2020.
5. Vérifiez à l'écran : 1 529 639 visites en 2020, 473 471 717 secondes.
6. Enregistrez la question sous le nom « Exercice 08 ».
7. Depuis le dossier du clone, lancez `./setup/check.sh 08`.

## Le contrôle

`check.sh` retrouve la question par son nom, l'exécute par l'API de Metabase et compare ses
lignes à celles de `reference.sql`, calculées dans psql sur la table de faits. Puis il lit ce que
la question lit : la table source de l'éditeur, ou les noms `entrepot.xxx` écrits dans son SQL.
L'une d'elles doit être une vue matérialisée du schéma `entrepot`, et aucune une table de ce
schéma. Une réponse juste finit ainsi :

```text
PASS: 6 rows, the same as the reference
PASS: reads the materialized view entrepot.visites_par_stage
PASS: the rows and the source are the ones asked for
Exercise 08: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 08"` | la question n'est pas enregistrée, ou elle est à la corbeille, ou son nom diffère | 2 |
| `FAIL source: the question reads entrepot.visite, which is not a materialized view` | les lignes sont justes, mais la question lit la table de faits | 3 |
| `FAIL rows` | un filtre, une autre agrégation, ou une vue qui ne couvre pas toutes les visites | 3 |
| `FAIL columns` | plus ou moins de trois colonnes, par exemple les visiteurs en plus, ou la durée oubliée | 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

Vérifiez aussi à la main dans psql, sur la vue puis sur la table :

```sql
select count(*) as visites, sum(duree) as duree
  from entrepot.visite
 where jour between date '2020-01-01' and date '2020-12-31';
```

La solution est dans `solution/`, à lire après avoir cherché : `matview.sql` crée la vue,
`exercice-08.json` est la question telle que l'API la crée, `create.sh` les recrée.

---

# Exercise of module 8

Create the fact table with `./setup/volume.sh` if needed. In psql, as `postgres`, create a
materialized view in the schema `entrepot` that counts the visits and adds up `duree` by month
and by course, from `entrepot.visite` (the name is yours). Sync the database in Metabase so that
it sees the view, then build a question on the view: by year, the sum of the visits and the sum
of the durations, three columns and six rows (2020: 1 529 639 visits, 473 471 717 seconds). Save
it as "Exercice 08" and run `./setup/check.sh 08` from the clone. The check runs the question
through the API of Metabase, compares its rows with `reference.sql` run in psql, then reads what
the question reads: one of its sources must be a materialized view of `entrepot`, and none a
table of that schema. The same rows read from `entrepot.visite` are refused. Exit codes:
0 passed, 1 lab, 2 missing question, 3 different rows or the fact table read instead of a
materialized view, 4 different columns. The solution is in `solution/`, to read after trying.
