# Corrigé de l'exercice du module 12

Relevé le 8 novembre 2026. Les versions et les licences viennent de l'API de GitHub, le reste des
pages citées, relues ce jour-là.

## Le tableau

| Outil | Licence du dépôt | Dernière version stable et date | Serveur MCP dans l'édition libre | Lit SQL Server |
|---|---|---|---|---|
| Superset | Apache-2.0 | 6.1.0, 13 mai 2026 (7.0.0rc2 du 16 octobre 2026 est une préversion) | oui : `superset/mcp_service`, dans la 6.1.0, absent de la 6.0.0 | oui, avec le pilote `pymssql` à installer |
| Grafana | AGPL-3.0 | 13.3.0, 27 octobre 2026 | oui : `mcp-grafana`, dépôt séparé, Apache-2.0, 2.2.0 du 2 novembre 2026 | oui, source SQL Server 2012 et plus |
| Rill | Apache-2.0 | 0.91.1, 3 novembre 2026 | oui, sur Rill Developer en local | non |
| Lightdash | `NOASSERTION` : MIT hors de `packages/backend/src/ee` | 3.179.0, 6 novembre 2026 | non : `MCP_ENABLED` exige `LIGHTDASH_LICENSE_KEY` | non |
| Evidence | MIT | CLI 0.12.1 ; ancien framework 40.1.8 du 6 février 2026 | non documenté | oui |

Sources :

- Superset : https://superset.apache.org/user-docs/using-superset/using-ai-with-superset/
  (« Requires Superset 5.0+ », contredit par le code),
  https://github.com/apache/superset/tree/6.1.0/superset/mcp_service,
  https://superset.apache.org/docs/databases/supported/microsoft-sql-server (« Required
  packages: pymssql »), https://superset.apache.org/user-docs/databases/ (« Superset does not
  ship bundled with connectivity to databases »).
- Grafana : https://grafana.com/docs/grafana/latest/datasources/mssql/,
  https://github.com/grafana/mcp-grafana (« Unified SQL tools support ClickHouse, Snowflake,
  Athena, MySQL, PostgreSQL, MSSQL, and BigQuery », outils SQL désactivés par défaut).
- Rill : https://docs.rilldata.com/guide/ai/mcp (« Locally Running Rill Developer »),
  https://docs.rilldata.com/developers/build/connectors (aucune entrée SQL Server).
- Lightdash : https://docs.lightdash.com/self-host/enterprise-features/mcp (« Requires
  `LIGHTDASH_LICENSE_KEY` »), https://docs.lightdash.com/get-started/setup-lightdash/connect-project
  (aucune entrée SQL Server).
- Evidence : https://docs.evidence.dev/direct-connectors/sqlserver ; aucune page lue ne documente
  un serveur MCP d'Evidence. La version de la CLI se lit dans le `version.json` que télécharge
  `https://evidence.studio/install.sh`.

## Les outils écartés

- Rill : il ne lit pas SQL Server.
- Lightdash : il ne lit pas SQL Server, et son serveur MCP demande une licence Enterprise en
  auto-hébergé.
- Evidence : il lit SQL Server, mais aucun serveur MCP n'est documenté. L'agent y écrit les
  fichiers (comme au module 11) ; il n'interroge pas un tableau de bord publié.

Restent Superset et Grafana, en plus de Metabase.

## Le premier essai

- Superset : monter l'image officielle de la 6.1, ajouter `pymssql` par
  `docker/requirements-local.txt`, connecter la base SQL Server, puis activer le serveur MCP et le
  brancher à Claude Code. Ni le pilote dans l'image ni le serveur MCP n'ont été mesurés pour ce
  cours.
- Grafana : créer la source SQL Server, lancer `mcp-grafana` avec `--enabled-tools` qui contient
  `sql`, et vérifier qu'une question de l'agent sur la base passe par la source de Grafana. Le
  modèle reste celui du client ; Grafana Assistant, lui, demanderait une pile Grafana Cloud.
- Pour les deux : rejouer le banc du module 9 sur la base de l'équipe, compter les réponses justes,
  dater la mesure.

---

# Solution of the exercise of module 12

Read on November 8, 2026. Superset (Apache-2.0, 6.1.0 of May 13, 2026, MCP service from 6.1.0,
SQL Server through the `pymssql` driver to install) and Grafana (AGPL-3.0, 13.3.0 of October 27,
2026, the separate `mcp-grafana` server under Apache-2.0 with its SQL tools disabled by default,
SQL Server 2012 and later) meet both conditions. Rill (no SQL Server), Lightdash (no SQL Server,
MCP behind an Enterprise license when self-hosted) and Evidence (no documented MCP server) do
not. The first test for Superset is the SQL Server driver in the official image and its MCP
server from Claude Code; for Grafana, `mcp-grafana` with the `sql` tools enabled against a SQL
Server data source. Then run the bench of module 9 and date the measurement.
