# Exercice du module 2

La direction veut savoir quels stages ont le plus de factures. Construisez dans l'éditeur de
Metabase, sans écrire de SQL, la liste des dix stages qui ont le plus de factures, chaque
facture comptée une seule fois pour chaque stage dont elle facture des inscriptions.

## Le travail demandé

1. Nouvelle question, éditeur, à partir de la table `Facture` de `pachadataformation`.
2. Joignez-y, comme dans la vidéo 2.3, `Inscriptionfacture`, `Inscription`, `Session` et
   `Stagelangue`.
3. Résumez par le nombre de valeurs distinctes de `Facturecd`, regroupé par le titre du stage.
4. Les factures qui ne se rattachent à aucune session n'ont pas de stage : elles ne font pas
   partie de la liste.
5. Triez par ce nombre, du plus grand au plus petit, et limitez à dix lignes.
6. Enregistrez la question sous le nom `Exercice 02`, dans la collection de votre choix.
7. Depuis le dossier du clone, lancez :

       ./setup/check.sh 02

Le contrôle retrouve la question par son nom, l'exécute et compare ses lignes à la requête de
`reference.sql`, jouée dans psql. Il compare les deux colonnes, le titre et le nombre, et pas
leur ordre : deux paires de stages sont ex aequo. Une réponse juste finit par :

    PASS: 10 rows, the same as the reference
    Exercise 02: passed.

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no question named "Exercice 02" ...` | aucune question enregistrée sous ce nom, ou elle est dans la corbeille | 2 |
| `FAIL error: the question does not run ...` | la question échoue quand Metabase l'exécute | 2 |
| `FAIL rows: different rows ...` | les lignes diffèrent ; `not expected:` et `missing:` disent lesquelles | 3 |
| `FAIL columns: ...` | pas deux colonnes, ou un texte là où la référence a un nombre | 4 |
| `FAIL lab: ...` | le labo ne répond pas, ou la clé d'API de `.env` est refusée | 1 |

La solution est dans `solution/` : `exercice-02.json`, la définition de la question telle que
l'API la crée (avec des noms à la place des identifiants), et `create.sh`, qui la recrée dans
Metabase. À lire après avoir cherché.

---

# Exercise of module 2

Build in the Metabase query builder, without SQL, the ten stages that have the most invoices,
each invoice counted once for each stage whose registrations it bills: start from `Facture`,
join `Inscriptionfacture`, `Inscription`, `Session` and `Stagelangue` as in video 2.3,
summarize by the number of distinct values of `Facturecd` grouped by the title of the stage,
leave out the invoices that reach no session (they have no stage), sort by that number in
descending order and limit to ten rows. Save the question as `Exercice 02` and run
`./setup/check.sh 02`: it finds the question by its name, runs it, and compares its rows with
`reference.sql` run in psql, without checking their order (two pairs of stages are tied). The
solution is in `solution/`, to read after trying: `exercice-02.json`, the definition of the
question as the API creates it (names in place of ids), and `create.sh`, which creates it again.
