#!/usr/bin/env bash
# Creates a question in Metabase from a JSON file, through the API, with the API key of .env.
# The solutions of the exercises and the demos use it: the continuous integration recreates
# their questions with it, then runs ./setup/check.sh.
# The file is the body of POST /api/card. The ids of the database, of the tables and of the
# columns change from one lab to another, so the file names them, as JSON strings that this
# script replaces with the ids of your lab:
#   "@database"                    the id of pachadataformation in Metabase
#   "@table:schema.table"          the id of a table, "@table:contact.contact" for instance
#   "@field:schema.table.column"   the id of a column, "@field:contact.contact.titre"
# Usage: ./setup/create-card.sh FILE.json
# Prints the id of the new question. Exit codes: 0 created; 1 the lab has a problem, a name of
# the file is unknown, or Metabase refuses the question.
set -uo pipefail
[ $# -eq 1 ] && [ -f "$1" ] || { echo "usage: $0 FILE.json" >&2; exit 1; }
file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
. "$(dirname "$0")/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mb_healthy || { echo "Metabase does not answer on $mb_url: start the lab with ./setup/install.sh." >&2; exit 1; }
[ -n "${MB_API_KEY:-}" ] || { echo "No API key in .env (MB_API_KEY): make one with ./setup/api-key.sh." >&2; exit 1; }

# The database pachadataformation, the sample database apart.
code=$(mb_call GET /api/database "$tmp/databases.json")
[ "$code" = 200 ] || { echo "Metabase refuses the API key of .env (HTTP $code)." >&2; exit 1; }
db=$(json_sql "$tmp/databases.json" "
    select d->>'id'
      from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d
     where d->'details'->>'dbname' = 'pachadataformation'
       and not coalesce((d->>'is_sample')::boolean, false)
     limit 1")
[ -n "$db" ] || { echo "pachadataformation is not connected in Metabase (module 1)." >&2; exit 1; }
code=$(mb_call GET "/api/database/$db/metadata" "$tmp/metadata.json")
[ "$code" = 200 ] || { echo "Metabase did not return the tables of the database $db (HTTP $code)." >&2; exit 1; }

# Each name of the file, replaced by its id.
body=$(cat "$file")
for name in $(grep -o '"@[a-z]*[^"]*"' "$file" | tr -d '"' | sort -u); do
    case "$name" in
        @database) id=$db ;;
        @table:*.*)
            ref=${name#@table:}
            id=$(json_sql "$tmp/metadata.json" "
                select t->>'id' from j, jsonb_array_elements(doc->'tables') t
                 where t->>'schema' = $(sql_text "${ref%%.*}") and t->>'name' = $(sql_text "${ref#*.}")") ;;
        @field:*.*.*)
            ref=${name#@field:}
            schema=${ref%%.*}; rest=${ref#*.}
            id=$(json_sql "$tmp/metadata.json" "
                select f->>'id' from j, jsonb_array_elements(doc->'tables') t, jsonb_array_elements(t->'fields') f
                 where t->>'schema' = $(sql_text "$schema") and t->>'name' = $(sql_text "${rest%%.*}")
                   and f->>'name' = $(sql_text "${rest#*.}")") ;;
        *) id= ;;
    esac
    [ -n "$id" ] || { echo "Unknown name in $file: $name" >&2; exit 1; }
    body=${body//"\"$name\""/$id}
done
printf '%s\n' "$body" > "$tmp/card.json"

code=$(mb_call POST /api/card "$tmp/created.json" "$tmp/card.json")
if [ "$code" != 200 ]; then
    echo "Metabase refused the question (HTTP $code): $(head -c 300 "$tmp/created.json")" >&2
    exit 1
fi
json_sql "$tmp/created.json" "select doc->>'id' || ' ' || (doc->>'name') from j"
