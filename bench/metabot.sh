#!/usr/bin/env bash
# Asks the questions of a bench file to Metabot, through the API of Metabase, one new
# conversation per question, as if each one were typed in a fresh Metabot chat.
# Usage: ./bench/metabot.sh [--again] [QUESTIONS] [Qnn ...]
#   QUESTIONS is a file of lines "Qnn|question" (bench/questions.txt by default; lines that
#   start with # are skipped). With Qnn, only those questions are asked.
#   --again asks nothing: it prints again the answers saved in work/metabot/ (no cost).
# Each question is sent to POST /api/metabot/agent-streaming with the API key of .env, which
# acts as an administrator: Metabot sees what that key sees. The answer is a stream of events
# (server-sent events), saved as it comes in work/metabot/<Qnn>.sse. The script then prints,
# for each question: the seconds it took, the databases Metabot queried (read in the queries it
# built), the tools it called, and the text of its answer, links to questions shortened to
# "(question)". The streams are read by PostgreSQL in the container, like every JSON document
# of setup/: bash and curl, nothing else.
# Each question costs a conversation with the model chosen in Admin > AI, paid to your AI
# provider (about 0.20 dollar a question with Claude Sonnet 4.6 through OpenRouter, measured
# on the lab of the course in November 2026).
# Exit codes: 0 every question got an answer; 1 the lab, the API key or the arguments; 2 at
# least one question ended on an error (the message is printed).
set -uo pipefail
. "$(dirname "$0")/../setup/lib.sh"

again=false
if [ "${1:-}" = --again ]; then again=true; shift; fi
questions=bench/questions.txt
if [ $# -gt 0 ] && [ -f "$1" ]; then questions=$1; shift; fi
[ -f "$questions" ] || { echo "No file $questions" >&2; exit 1; }
only=" $* "

mb_healthy || { echo "Metabase does not answer on $mb_url: start the lab with ./setup/install.sh." >&2; exit 1; }
[ -n "${MB_API_KEY:-}" ] || { echo "No API key in .env (MB_API_KEY): make one with ./setup/api-key.sh." >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
out=work/metabot
mkdir -p "$out"

# The databases of Metabase, to print their names next to the ids Metabot queried.
[ "$(mb_call GET /api/database "$tmp/databases.json")" = 200 ] \
    || { echo "Metabase refuses the API key of .env: make a new one with ./setup/api-key.sh --force." >&2; exit 1; }
names=$(json_sql "$tmp/databases.json" "
    select string_agg(d->>'id' || '=' || (d->>'name'), ';')
      from j, jsonb_array_elements(case jsonb_typeof(doc) when 'array' then doc else doc->'data' end) d")

# A random version 4 UUID, for the conversation, in bash alone.
uuid() {
    printf '%04x%04x-%04x-4%03x-%04x-%04x%04x%04x\n' $RANDOM $RANDOM $RANDOM $((RANDOM % 4096)) \
        $(((RANDOM % 16384) | 32768)) $RANDOM $RANDOM $RANDOM
}

# sse_sql FILE SQL: loads the events of the stream FILE into the temporary table e (n, the
# order of the event; doc, the event as jsonb), runs SQL and prints the result.
sse_sql() {
    {
        echo '\set ON_ERROR_STOP on'
        echo 'create temp table e (n serial, doc jsonb);'
        echo 'copy e (doc) from stdin;'
        sed -n 's/^data: \({.*}\)\r\{0,1\}$/\1/p' "$1" | sed 's/\\/\\\\/g'
        printf '\\.\n'
        printf '%s\n' "$2"
    } | psql_lab -d postgres -q -At
}

failed=0
asked=0
while IFS='|' read -r id question || [ -n "$id" ]; do
    id=${id%$'\r'} question=${question%$'\r'}
    case "$id" in ''|'#'*) continue;; esac
    if [ "$only" != "  " ] && [[ $only != *" $id "* ]]; then continue; fi
    asked=$((asked + 1))
    printf '{"message":%s,"context":{},"conversation_id":"%s","metabot_id":"metabotmetabotmetabot"}\n' \
        "$(json_text "$question")" "$(uuid)" > "$tmp/request.json"
    start=$SECONDS
    if [ "$again" = true ]; then
        [ -f "$out/$id.sse" ] || { echo "== $id: no saved answer in $out"; failed=1; continue; }
        code=202
        echo "== $id (saved answer): $question"
    else
        code=$(curl -sS -N --max-time 600 -o "$out/$id.sse" -w '%{http_code}' -X POST \
            -H 'Content-Type: application/json' -H @<(printf 'X-API-Key: %s\n' "$MB_API_KEY") \
            --data-binary "@$tmp/request.json" "$mb_url/api/metabot/agent-streaming" 2>/dev/null || true)
        echo "== $id ($((SECONDS - start)) s): $question"
    fi
    # The stream is answered with 202 Accepted.
    if [ "$code" != 202 ] && [ "$code" != 200 ]; then
        echo "   ERROR: HTTP $code: $(head -c 300 "$out/$id.sse")"
        failed=1
        continue
    fi
    sse_sql "$out/$id.sse" "
        with names as (
            select split_part(x, '=', 1) as id, split_part(x, '=', 2) as name
              from unnest(string_to_array($(sql_text "$names"), ';')) x),
        dbs as (
            select distinct m[1] as id
              from e, regexp_matches(coalesce(doc->>'output', ''), '<query [^>]*database_id=\"([0-9]+)\"', 'g') m
             where doc->>'type' = 'tool-output-available'),
        answer as (
            select string_agg(doc->>'delta', '' order by n) as t from e where doc->>'type' = 'text-delta')
        select '   databases: ' || coalesce((select string_agg(d.id || ' ' || coalesce(n.name, '?'), ', ' order by d.id)
                                              from dbs d left join names n using (id)), 'none')
        union all
        select '   tools: ' || coalesce((select string_agg(doc->>'toolName', ', ' order by n) from e
                                           where doc->>'type' = 'tool-input-available'), 'none')
        union all
        select '   ERROR: ' || (doc->>'errorText') from e where doc->>'type' = 'error'
        union all
        select '   answer: ' || coalesce(regexp_replace(regexp_replace((select t from answer),
                   '\(/question#[^)]*\)', '(question)', 'g'), '\s+', ' ', 'g'), '(no text)');" > "$tmp/summary.txt"
    cat "$tmp/summary.txt"
    grep -q '^   ERROR: ' "$tmp/summary.txt" && failed=1
done < "$questions"

[ "$asked" -gt 0 ] || { echo "No question asked: check the file and the ids given." >&2; exit 1; }
if [ "$failed" = 1 ]; then exit 2; fi
exit 0
