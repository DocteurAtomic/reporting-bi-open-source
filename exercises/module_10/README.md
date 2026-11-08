# Exercice du module 10

Le service commercial veut savoir quelles sociétés ont envoyé des stagiaires en 2019 : pour
chaque société, le nombre d'inscriptions qui ne sont ni annulées ni en liste d'attente, sur les
sessions qui commencent en 2019. Cette fois, ce n'est pas vous qui construisez la question :
vous la faites créer par Claude Code, par le serveur MCP de Metabase, et vous la contrôlez.

## Le travail demandé

1. Si ce n'est pas fait, branchez Claude Code sur le serveur MCP de Metabase, comme dans la
   vidéo 10.1 : `claude mcp add --transport http metabase http://localhost:3000/api/metabase-mcp`
   dans le dossier du clone, puis `/mcp` dans Claude Code pour autoriser la connexion.
2. Avant de lancer l'agent, écrivez dans psql, sous `lecture_bi`, votre requête de référence :
   une ligne par société, deux colonnes, le nom de la société et le nombre d'inscriptions. Notez
   le nombre de lignes et le total.
3. Écrivez votre demande à Claude Code. Elle doit nommer la question, « Exercice 10 », la base,
   `pachadataformation`, les trois conditions (ni annulée, ni en liste d'attente, session qui
   commence en 2019), et les deux colonnes. Dites aussi ce que l'agent ne doit pas toucher.
4. Lisez sa réponse, puis la question qu'il a enregistrée, dans Metabase : sa source, ses
   jointures, ses filtres. Comparez son total au vôtre.
5. Depuis le dossier du clone, lancez `./setup/check.sh 10`.

## Le contrôle

`check.sh` retrouve la question « Exercice 10 » par son nom, l'exécute par l'API de Metabase et
compare ses lignes à celles de `reference.sql`, jouée dans psql. Il ne note pas l'agent : il
contrôle la question enregistrée, quelle que soit la façon dont elle a été construite. Une
réponse juste finit ainsi :

```text
PASS: 85 rows, the same as the reference
Exercise 10: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 10"` | la question n'est pas enregistrée, elle est à la corbeille, ou l'agent lui a donné un autre nom | 2 |
| `FAIL rows`, `not expected: (empty) \| 128` | les inscriptions des contacts sans société sont comptées, sur une ligne sans nom (jointure externe) | 3 |
| `FAIL rows`, `123 rows instead of 85` | les inscriptions en liste d'attente sont comptées | 3 |
| `FAIL rows`, `86 rows instead of 85` et des nombres plus grands | les inscriptions annulées sont comptées | 3 |
| `FAIL rows`, `98 rows instead of 85` | l'année est celle de la création de l'inscription, et non celle de la session | 3 |
| `FAIL columns` | une colonne de plus, l'identifiant de la société par exemple | 4 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

Un `FAIL` ne se corrige pas en réécrivant la question à la main : redemandez à l'agent, en
précisant ce qui manquait à votre demande, et relancez le contrôle.

La solution est dans `solution/`, à lire après avoir cherché : `exercice-10.json` est la
question que Claude Code a construite sur le labo du cours, réécrite sous la forme de l'éditeur
de questions, et `create.sh` la recrée par l'API, pour l'intégration continue.

---

# Exercise of module 10

The sales department wants to know which companies sent trainees in 2019: for each company, the
number of registrations that are neither cancelled nor on the waiting list, on the sessions that
start in 2019. Have Claude Code create this question through the MCP server of Metabase (video
10.1 connects it), after writing your own reference query in psql as `lecture_bi`. Your request
must name the question "Exercice 10", the database `pachadataformation`, the three conditions
and the two columns (the name of the company, the number of registrations). Then run
`./setup/check.sh 10` from the clone. The check runs the saved question through the API of
Metabase and compares its rows with `reference.sql` run in psql: 85 companies. A line without a
name for the contacts without a company, registrations on the waiting list, cancelled ones, or
the year of creation of the registration instead of the year of the session each give 3; an
extra column gives 4. Exit codes: 0 passed, 1 lab, 2 missing question, 3 different rows,
4 different columns. The solution is in `solution/`, to read after trying.
