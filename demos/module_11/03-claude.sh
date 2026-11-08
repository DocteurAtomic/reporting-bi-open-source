#!/usr/bin/env bash
# Video 11.3: asks Claude Code for the billing page of video 11.2, in a folder of its own.
# Claude Code runs without a prompt to answer (claude -p) and with two rights only: write in
# that folder (--permission-mode acceptEdits accepts the edits inside the working folder and
# nowhere else), and run psql as lecture_bi, which can only read. Any other command is refused.
# It needs Claude Code installed and logged in (a Claude subscription or an API key): each run
# is a conversation of a minute or two, billed to your account.
# The page lands in FOLDER/facturation-claude.sql (work/claude by default, never committed);
# copy it to site/ to see it in SQLPage and check it (video 11.4). The whole conversation is
# kept in FOLDER/claude.jsonl, its last line is the report of the agent.
# Usage: ./demos/module_11/03-claude.sh [FOLDER]
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
command -v claude >/dev/null 2>&1 || { echo "Claude Code (claude) is not installed." >&2; exit 1; }
lab_running "$c" || { echo "The container $c is not running; start the lab with ./setup/install.sh" >&2; exit 1; }
dir=${1:-work/claude}
mkdir -p "$dir"
psql_cmd="$engine exec -i $c psql -U lecture_bi -d pachadataformation"

demande="La facturation veut une page simple pour l'intranet, écrite pour SQLPage 0.47 : \
un fichier facturation-claude.sql dans ce dossier. La base est pachadataformation, sur \
PostgreSQL 18. Tu la lis par psql, avec la commande « $psql_cmd », sous le rôle lecture_bi, \
qui ne fait que lire. La page montre le nombre de factures qui n'ont reçu aucun paiement, ces \
factures par année de facture en graphique, et les dix sociétés les plus facturées hors taxes, \
toutes années confondues, en tableau. Tu ne peux pas ouvrir la page dans SQLPage : vérifie \
chaque chiffre dans psql, par une requête écrite autrement que celle de la page. Puis dis-moi \
ce que tu as vérifié, ce que tu as écarté, et pourquoi."

cd "$dir" || exit 1
start=$SECONDS
claude -p "$demande" \
    --model sonnet \
    --tools "Bash,Read,Write,Edit,Glob,Grep" \
    --permission-mode acceptEdits \
    --allowedTools "Bash($psql_cmd:*)" \
    --strict-mcp-config --setting-sources "" --no-session-persistence \
    --output-format stream-json --verbose < /dev/null > claude.jsonl
code=$?
echo "Claude Code ended with code $code after $((SECONDS - start)) s; conversation in $dir/claude.jsonl."
[ -f facturation-claude.sql ] && echo "Page written: $dir/facturation-claude.sql" \
    || echo "No facturation-claude.sql in $dir: read the end of $dir/claude.jsonl."
exit "$code"
