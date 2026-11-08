# Exercice du module 9

La direction veut savoir si elle peut se fier à Metabot pour ses questions courantes. Vous posez
à Metabot dix questions qu'elle pourrait poser, vous vérifiez chaque réponse par une requête
écrite à la main, et vous notez vos verdicts dans un fichier.

## Le travail demandé

1. Si ce n'est pas fait, branchez un fournisseur et choisissez le modèle de Metabot (vidéo 9.1),
   et supprimez la base d'exemple : `./demos/module_09/03-sample.sh --remove`.
2. Posez à Metabot les dix questions de `exercises/module_09/questions.txt`, une conversation
   neuve par question : dans le panneau de Metabot (nouvelle conversation à chaque fois), ou par
   l'API, `./bench/metabot.sh exercises/module_09/questions.txt`. Comptez une dizaine de
   minutes et deux à trois dollars.
3. Pour chaque réponse, ouvrez la requête de Metabot (le lien de sa réponse, ou
   `./demos/module_09/02-query.sh E01`), puis écrivez dans psql, sous `lecture_bi`, votre propre
   requête. Quand la question a deux lectures, écrivez les deux.
4. Notez chaque réponse dans `work/answer09.csv`, une ligne par question, champs séparés par
   des points-virgules :

   ```text
   question;chiffre;verdict;lecture
   E01;1 234;juste;la lecture que Metabot a choisie
   E02;56,78;faux;une autre table que celle de la question
   ```

   - `question` : `E01` à `E10` ;
   - `chiffre` : le nombre que Metabot a donné, écrit en entier (`22486000`, `22 486 000` ou
     `3451,95` ; espaces, `%`, `€` et virgule décimale acceptés) ;
   - `verdict` : `juste` si le chiffre est celui d'une lecture de la question, `faux` sinon ;
   - `lecture` : la lecture que Metabot a choisie, en vos mots (texte libre, non contrôlé).
5. Depuis le dossier du clone, lancez `./setup/check.sh 09`.

## Le contrôle

`check.sh` ne note pas Metabot, il contrôle vos verdicts. Il lit `work/answer09.csv` et compare
chaque ligne aux lectures que calcule `reference.sql` dans psql : une ligne par question, chaque
`juste` égal à l'une des lectures, chaque `faux` égal à aucune, à la précision écrite (`3452`
vaut `3451,95`). Il n'affiche jamais les valeurs de référence. Une réponse juste finit ainsi :

```text
PASS: 10 answers, 8 marked juste and 2 marked faux, each verdict agrees with the reference
Exercise 09: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no file work/answer09.csv` | le fichier n'existe pas, ou il est vide | 2 |
| `FAIL rows: E03 is marked juste with …, which matches none of the readings` | vous avez jugé juste un chiffre qui ne l'est pas : refaites la requête | 3 |
| `FAIL rows: E10 is marked faux with …, which matches one of the readings` | Metabot avait raison : votre requête ou votre lecture diffère | 3 |
| `FAIL rows: no line for E07`, `is answered 2 times`, `is not a question of the exercise` | une question manque, revient deux fois, ou n'existe pas | 3 |
| `FAIL columns: E05, "…" is not a number` | le chiffre n'est pas écrit en entier, ou contient du texte | 4 |
| `FAIL columns: E05, the verdict is "…"` | le verdict n'est ni `juste` ni `faux` | 4 |
| `FAIL columns: line 6 has 1 field(s)` | une ligne sans ses points-virgules | 4 |
| `FAIL lab` | le labo est arrêté, ou la clé d'API de `.env` est refusée (module 1) | 1 |

Comptez ensuite vos `juste` : c'est le taux de Metabot sur votre instance, ce jour-là.

La solution est dans `solution/`, à lire après avoir cherché : `answer09.csv` est le fichier
écrit après les réponses de Metabot du 8 novembre 2026, `metabot-2026-11-08.txt` ces réponses,
et `create.sh` recopie le fichier dans `work/` pour l'intégration continue.

---

# Exercise of module 9

Connect an AI provider and pick the model of Metabot (video 9.1), and remove the sample database
(`./demos/module_09/03-sample.sh --remove`). Ask Metabot the ten questions of
`exercises/module_09/questions.txt`, one new conversation each, in the Metabot panel or with
`./bench/metabot.sh exercises/module_09/questions.txt` (about ten minutes and two to three dollars). For
each answer, read the query of Metabot (the link of its answer, or
`./demos/module_09/02-query.sh E01`) and write your own query in psql as `lecture_bi`, both
readings when the question has two. Write one line per question in `work/answer09.csv`, fields
separated by semicolons: `question;chiffre;verdict;lecture` (the id E01 to E10, the number
Metabot gave written in full, `juste` or `faux` as you judged it, and the reading Metabot chose,
in your words). Run `./setup/check.sh 09` from the clone. The check does not grade Metabot: it
checks that each `juste` equals one of the readings computed by `reference.sql`, at the
precision written, and each `faux` none of them, without printing the reference values. Exit
codes: 0 passed, 1 lab, 2 missing file, 3 a missing, repeated or unknown question, or a verdict
that disagrees with the reference, 4 a line without its fields, a number that is not one, or a
verdict that is neither `juste` nor `faux`. The solution is in `solution/`, to read after
trying.
