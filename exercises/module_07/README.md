# Exercice du module 7

Le planning demande ses propres comptes dans Metabase. Il veut construire des questions sur ses
tables, les sessions, les stages, les salles et les lieux, sans écrire de SQL, et sans voir les
questions de la facturation.

Avant de commencer, les connexions du clip 7.1 doivent exister : `./setup/roles.sh`, puis
« Données du planning » (sous `lecture_planning`) et « Données de la facturation » (sous
`lecture_facturation`), créées dans Administration, Bases de données, ou par
`./demos/module_07/01-connections.sh`.

## Le travail demandé

1. Restreignez d'abord All Users : création de requêtes à « Non » sur chaque connexion, s'il ne
   l'est pas déjà depuis le clip 7.1.
2. Créez le groupe « Planning » (Administration, Personnes, Groupes).
3. Donnez-lui la création de requêtes par l'éditeur seul sur « Données du planning », sans SQL,
   et rien sur les autres connexions.
4. Créez un compte, par exemple `planning@pachadata.example`, et mettez-le dans le groupe.
5. Fermez la collection « Facturation » au groupe Planning comme à All Users : aucun accès.
6. Connectez-vous sous ce compte, dans une fenêtre privée, et vérifiez : une question sur
   Session, nombre de lignes, rend 3 039 ; l'éditeur SQL n'est pas proposé ; la collection
   « Facturation » n'apparaît pas.
7. Depuis le dossier du clone, lancez `./setup/check.sh 07`.

## Le contrôle

`check.sh` lit le groupe et ses comptes, le graphe des droits et celui des collections, puis
fabrique une clé d'API temporaire dans le groupe Planning et essaie sous elle : le nombre de
sessions sur « Données du planning » par l'éditeur (comparé à `reference.sql`), les factures sur
« Données de la facturation » (refusées), une requête SQL sur « Données du planning »
(refusée), et la liste des collections (sans « Facturation »). La clé est supprimée à la fin.
Une réponse juste finit ainsi :

```text
PASS: the group counts 3039 rows in stage.session with the query builder, like the reference
PASS: inscription.facture on "Données de la facturation" refused to the group (HTTP 403)
PASS: SQL on "Données du planning" refused to the group (HTTP 403)
PASS: the group "Planning" queries its connection with the query builder only, and does not see "Facturation"
Exercise 07: passed.
```

| Ce que vous lisez | Cause | Code |
|---|---|---|
| `FAIL missing: no group named "Planning"` | le groupe n'existe pas, ou son nom diffère | 2 |
| `FAIL missing: the group "Planning" has no account` | aucun compte dans le groupe (une clé d'API ne compte pas) | 2 |
| `FAIL missing: no connection of Metabase reads pachadataformation as lecture_planning` | la connexion du clip 7.1 manque | 2 |
| `FAIL rows: All Users can still create queries on …` | All Users n'est pas restreint ; ses droits s'ajoutent à ceux du groupe | 3 |
| `FAIL rows: the group "Planning" can still write SQL on "Données du planning"` | le SQL est resté au groupe, souvent parce qu'il a été créé avant la restriction de All Users et en a copié les droits | 3 |
| `FAIL rows: the group "Planning" can create queries on "…", which is not its connection` | un droit sur une autre connexion | 3 |
| `FAIL rows: … can open the collection "Facturation"` | la collection est restée ouverte à All Users ou au groupe | 3 |
| `FAIL lab` | le labo, Metabase ou la clé d'API de `.env` (module 1) | 1 |

Vérifiez aussi dans psql, sous le rôle de la connexion :

```bash
docker compose exec db psql -U lecture_planning -d pachadataformation -c 'select count(*) from stage.session'
docker compose exec db psql -U lecture_planning -d pachadataformation -c 'select count(*) from inscription.facture'
```

La première rend 3 039, la seconde `permission denied for schema inscription`.

La solution est dans `solution/`, à lire après avoir cherché : `create.sh` fait les cinq
premiers gestes par l'API.

---

# Exercise of module 7

The planning service wants its own accounts. Restrict the group All Users first (create
queries: no, on every connection). Create the group "Planning", give it the query builder only
(no SQL) on the connection "Données du planning" (read as `lecture_planning`, clip 7.1) and
nothing elsewhere, add an account to it, and close the collection "Facturation" to Planning and
to All Users (no access). Then run `./setup/check.sh 07` from the clone. The check reads the
group, the permission graph and the collection graph, then makes a temporary API key in the
group and tries under it: the count of `stage.session` on the planning connection must be
3 039, the invoices on the invoicing connection and SQL on the planning connection must be
refused, and the collection must stay hidden. A group created before All Users was restricted
copies its rights, SQL included. Exit codes: 0 passed, 1 lab, 2 missing group, account or
connection, 3 a right wider than the one asked. The solution is in `solution/`, to read after
trying.
