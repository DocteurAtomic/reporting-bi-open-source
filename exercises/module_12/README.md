# Exercice du module 12

Une autre équipe de l'organisme a ses données dans SQL Server. Elle veut des tableaux de bord
qu'un agent comme Claude Code interroge et modifie par un serveur MCP, sans licence payante. Elle
vous demande quels outils libres répondent à ces deux conditions, à la date du jour.

Cet exercice n'a pas de `check.sh` : ses réponses changent à chaque version des outils, et un
contrôle figé dans le dépôt deviendrait faux sans prévenir. Vous le vérifiez contre les pages
officielles, et le corrigé daté est dans `solution/`.

## Le travail demandé

1. Recopiez ce tableau et remplissez-le pour Superset, Grafana, Rill, Lightdash et Evidence,
   depuis les pages officielles et les dépôts. Chaque case donne sa source et sa date de
   lecture.

   | Outil | Licence du dépôt | Dernière version stable et date | Serveur MCP dans l'édition libre | Lit SQL Server | Source et date |
   |---|---|---|---|---|---|
   | Superset | | | | | |
   | Grafana | | | | | |
   | Rill | | | | | |
   | Lightdash | | | | | |
   | Evidence | | | | | |

2. Écartez les outils qui manquent l'une des deux conditions, en disant laquelle.
3. Pour chaque outil restant, écrivez le premier essai à faire avant de le promettre à l'équipe :
   ce que la documentation ne garantit pas et qu'il faut mesurer.

## Les commandes utiles

La licence et la dernière version stable se lisent par l'API publique de GitHub, sans compte :

```bash
curl -s https://api.github.com/repos/apache/superset/license | grep '"spdx_id"'
curl -s https://api.github.com/repos/apache/superset/releases/latest | grep -E '"tag_name"|"published_at"'
```

Dépôts : `apache/superset`, `grafana/grafana`, `grafana/mcp-grafana`, `rilldata/rill`,
`lightdash/lightdash`, `evidence-dev/evidence`. Une licence `NOASSERTION` veut dire que le
fichier `LICENSE` a plusieurs parties : lisez-le. Le reste se lit dans la documentation de chaque
outil : la page de son serveur MCP, la liste de ses sources de données.

## La vérification des cases

- Une case « non » se prouve par la liste entière : la page des connecteurs, cherchée par
  « SQL Server » et « MSSQL ».
- Une case « oui » se prouve par la phrase de la page, recopiée.
- Une version candidate (`rc`) ou marquée « Pre-release » n'est pas une version stable.

Le corrigé, à lire après avoir cherché : `solution/README.md`, daté du 8 novembre 2026. Si vos
cases diffèrent, regardez d'abord la date : un outil a peut-être changé depuis.

---

# Exercise of module 12

Another team of the organization keeps its data in SQL Server. It wants dashboards that an agent
such as Claude Code reads and changes through an MCP server, without a paid license. Fill the
table above for Superset, Grafana, Rill, Lightdash and Evidence from the official pages and
repositories: license of the repository, latest stable version and its date, an MCP server in the
free edition, SQL Server support, and the source of each cell with the date you read it. Then
drop the tools that miss one of the two conditions, and for each remaining tool write the first
test to run before promising it to the team. There is no `check.sh` for this exercise: the
answers change with every release, and a check frozen in the repository would turn wrong
silently. The commands above read the license and the latest release through the public API of
GitHub. A "no" is proven by the whole list of connectors, a "yes" by the sentence of the page.
The dated solution is in `solution/README.md` (November 8, 2026), to read after trying.
