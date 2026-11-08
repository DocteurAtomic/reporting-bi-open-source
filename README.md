# Reporting BI open source, avec ou sans IA

Labo, démonstrations et exercices du cours en ligne
[« Reporting BI open source, avec ou sans IA »](https://www.docteuratomic.com) de Docteur
Atomic : construire les questions et les tableaux de bord d'un organisme de formation avec
Metabase et SQLPage, d'abord sans IA, puis avec Metabot et avec Claude Code par le serveur MCP
de Metabase, en vérifiant chaque chiffre dans la base.

## Le poste

- Docker (ou Podman) avec `compose`, `curl` et un shell bash (sous Windows, WSL2 ou Git
  Bash) ;
- 4 Go de mémoire libre et 3 Go de disque : les images de PostgreSQL (464 Mo), de Metabase
  (1,08 Go) et de SQLPage (39 Mo), la base (81 Mo) ; Metabase occupe à lui seul 1,7 à 2 Go
  de mémoire ;
- aucun client PostgreSQL ni `jq` : psql tourne dans le conteneur, et les scripts lisent les
  réponses JSON de Metabase avec PostgreSQL.

## Le labo

    git clone https://github.com/DocteurAtomic/reporting-bi-open-source.git
    cd reporting-bi-open-source
    ./setup/install.sh

`install.sh` écrit `.env` avec trois mots de passe tirés au hasard : celui de `postgres`,
celui du rôle `metabase` (propriétaire de la base applicative de Metabase) et celui du rôle
`lecture_bi` (le fichier n'est jamais versionné ; `.env.example` montre ce qu'il contient). Il
télécharge la sauvegarde de la base `pachadataformation` (23 Mo), vérifie sa somme SHA-256,
démarre PostgreSQL 18, restaure la base, ramène les adresses électroniques sur des domaines
`.example` et compacte les tables. Il crée ensuite le rôle `lecture_bi`, qui ne peut que se
connecter à `pachadataformation`, utiliser ses schémas et lire ses tables (y compris celles
créées plus tard), et la base `metabase`. Il démarre enfin Metabase 0.65.3 et attend qu'il
réponde. Une fois les images téléchargées, l'installation prend moins d'une minute. Il se
relance sans danger : `.env`, la sauvegarde, la base et les rôles déjà présents sont gardés.

Docker est employé quand il est installé, Podman sinon. Avec Podman, `podman compose`
demande `podman-compose` ou `docker-compose` ; sans eux :
`COMPOSE="uvx podman-compose" ./setup/install.sh`.

| Service | Adresse | Conteneur |
|---|---|---|
| Metabase | `http://localhost:3000` | `bicourse-metabase` |
| PostgreSQL | `127.0.0.1:5433` | `bicourse` |
| SQLPage (module 11) | `http://localhost:8080` | `bicourse-sqlpage` |

Les ports se changent dans `.env` (`MBPORT`, `PGPORT`, `SQLPAGEPORT`) avant le premier
démarrage. PostgreSQL écoute sur 5433 et non 5432, pour ne pas gêner le labo d'un autre cours.

Le compte administrateur de Metabase n'est pas créé par le script : vous le créez dans le
navigateur au module 1, et vous y connectez la base (hôte `db`, port 5432, base
`pachadataformation`, utilisateur `lecture_bi`, mot de passe `LECTURE_BI_PASSWORD` de `.env`).
Le module 1 vous fait ensuite créer la clé d'API que lisent les contrôles :

    ./setup/api-key.sh

Le script demande l'adresse et le mot de passe de l'administrateur, crée une clé d'API du
groupe Administrateurs et l'écrit dans `.env` (`MB_API_KEY`) sans l'afficher.

Se connecter avec psql, sans mot de passe, dans le conteneur :

    docker compose exec db psql -U postgres -d pachadataformation

SQLPage n'est lancé qu'au module 11 : `docker compose --profile code up -d`. Le dossier `site/`
du dépôt est monté dans le conteneur, et SQLPage lit la base sous `lecture_bi`.

Metabot (module 9) demande une clé chez un fournisseur d'IA : écrivez-la dans `.env` sous
`MB_LLM_OPENROUTER_API_KEY`, puis `docker compose up -d metabase`. Elle ne va jamais dans un
script ni dans une capture.

## Les exercices

Chaque exercice se fait dans Metabase : vous enregistrez votre question sous le nom que
l'énoncé impose (« Exercice 03 »), puis vous lancez :

    ./setup/check.sh 03

Le contrôle retrouve la question par son nom avec la clé d'API, l'exécute, et compare ses
lignes à celles de la requête de référence de l'exercice (`exercises/module_NN/reference.sql`),
jouée dans psql. Les nombres sont comparés à six décimales près, les dates sans fuseau.
`./setup/check.sh 00` contrôle le labo : Metabase répond, la clé d'API est acceptée, une seule
base est connectée en dehors de la base d'exemple (`pachadataformation`, sous `lecture_bi`), et
`lecture_bi` ne fait que lire. Le contrôle finit par `PASS`, ou par une ligne `FAIL` qui dit
ce qui ne va pas, et son code de sortie le répète :

| Code | Ce qu'il veut dire |
|---|---|
| 0 | la réponse est juste |
| 1 | le labo ou le contrôle a un problème (conteneur arrêté, Metabase muet, clé d'API absente ou refusée) |
| 2 | la question manque, est dans la corbeille ou échoue à l'exécution |
| 3 | les lignes diffèrent, avec les deux comptes et les premières différences |
| 4 | les colonnes diffèrent (leur nombre, ou du texte là où la référence a des nombres) |

L'ordre des lignes n'est contrôlé que quand l'énoncé le demande.

## Le contenu

Ce dépôt se remplit module par module ; l'étiquette `module-NN-start` marque l'état où
commence chaque module.

- `demos/module_NN/` : les requêtes de vérification et les scripts joués dans les vidéos.
- `exercises/module_NN/` : l'exercice du module et sa requête de référence.
- `bench/` : le banc de questions posé à Metabot et à Claude Code (partie 4).
- `site/` : les pages SQLPage.
- `setup/` : l'installation, l'anonymisation, la clé d'API, les contrôles.
- `work/` : vos fichiers, jamais versionnés.

Jouez ces scripts sur le labo, jamais sur un serveur de production.

## La base

`pachadataformation` est le portage PostgreSQL de la base de démonstration
PachaDataFormation de Rudi Bruchez : un organisme de formation fictif, ses stages, sessions,
inscriptions et factures. Les personnes sont fictives, et leurs adresses sont ramenées sur
des domaines `.example` à l'installation. La sauvegarde n'est pas dans ce dépôt, le script la
télécharge.

## Licence

Le code est sous licence MIT ([`LICENSE`](LICENSE)). Metabase est sous licence AGPL (hors de
son dossier `enterprise/`), SQLPage sous licence MIT ; leurs images sont téléchargées depuis
Docker Hub.

---

# Open-source BI reporting, with or without AI

Lab, demos and exercises of the Docteur Atomic online course: build the questions and the
dashboards of a training organization with Metabase and SQLPage, first without AI, then with
Metabot and with Claude Code through the MCP server of Metabase, checking every figure against
the database.

You need Docker (or Podman) with compose, curl and bash (WSL2 or Git Bash on Windows), 4 GB of
free memory and 3 GB of free disk. Run `./setup/install.sh`: it writes `.env` with three random
passwords (`postgres`, the role `metabase` and the read-only role `lecture_bi`, never committed),
downloads the `pachadataformation` dump and checks its SHA-256, starts PostgreSQL 18 in the
`bicourse` container, restores the database, moves every email address to a `.example` domain,
creates the role `lecture_bi` (connect, usage and select only, default privileges included) and
the application database of Metabase, then starts Metabase 0.65.3 and waits for it. With Podman
and no compose provider: `COMPOSE="uvx podman-compose" ./setup/install.sh`.

Metabase is on `http://localhost:3000`, PostgreSQL on `127.0.0.1:5433`, SQLPage (module 11,
`docker compose --profile code up -d`) on `http://localhost:8080`; `MBPORT`, `PGPORT` and
`SQLPAGEPORT` in `.env` change the ports. The administrator account of Metabase is created by
hand in module 1, which then runs `./setup/api-key.sh`: it asks for the administrator's email
and password, creates an API key in the Administrators group and writes it to `.env`
(`MB_API_KEY`) without printing it. The key of the AI provider of Metabot (module 9) goes in
`.env` under `MB_LLM_OPENROUTER_API_KEY`.

Save the question of exercise NN in Metabase as "Exercice NN" and run `./setup/check.sh NN`: it
finds the question by its name with the API key, runs it, and compares its rows with the
reference query of the exercise run in psql (numbers to six decimals, dates without time zone,
order ignored unless the exercise asks for it). `./setup/check.sh 00` checks the lab. It exits
with 0 (right), 1 (lab problem), 2 (question missing, in the trash or failing), 3 (different
rows) or 4 (different columns). `demos/` holds the scripts shown in the videos, `exercises/`
the exercises, `bench/` the questions asked to Metabot and Claude Code, `site/` the SQLPage
pages. The code is released under the MIT license.
