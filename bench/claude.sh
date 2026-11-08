#!/usr/bin/env bash
# Asks the questions of a bench file to Claude Code, through the MCP server of Metabase, one
# new session per question (claude -p), with the tools of that server as its only tools.
# Usage: ./bench/claude.sh [--again] [QUESTIONS] [Qnn ...]
#   QUESTIONS is a file of lines "Qnn|question" (bench/questions.txt by default; lines that
#   start with # are skipped). With Qnn, only those questions are asked.
#   --again asks nothing: it prints again the answers saved in work/claude/ (no cost).
# Claude Code must know the server first: claude mcp add --transport http metabase
# http://localhost:3000/api/metabase-mcp, then /mcp in Claude Code to authorize it (module 10).
# The script uses that server, named metabase (MCP_SERVER changes the name), with your own
# settings of Claude Code (CLAUDE.md files, hooks), as in a session you would open yourself.
# To run Claude Code apart from them, with a configuration file of MCP servers and nothing
# else, set MCP_CONFIG to the path of that file: the script then passes --strict-mcp-config
# --mcp-config "$MCP_CONFIG" --setting-sources "".
# Each question runs as: claude -p "<question> <ANSWER_RULE>" --model "$CLAUDE_MODEL" (sonnet by
# default) --tools "" (no file, shell or web tool) --allowedTools mcp__<server> (every tool of the
# server, without asking) --no-session-persistence --output-format stream-json --verbose.
# The stream is saved as it comes in work/claude/<Qnn>.jsonl. The script then prints, for each
# question: the seconds it took, the turns, the tools called and the databases they named, the
# calls that failed, and the answer (its first WIDTH characters, 600 by default). The streams
# are read by PostgreSQL in the container, like every JSON document of setup/: bash and curl,
# nothing else.
# Each question uses your Claude subscription or your API key, at the rate of your plan.
# Exit codes: 0 every question got an answer; 1 the lab, claude or the arguments; 2 at least
# one question ended without an answer or on an error (the message is printed).
set -uo pipefail
. "$(dirname "$0")/../setup/lib.sh"

again=false
if [ "${1:-}" = --again ]; then again=true; shift; fi
questions=bench/questions.txt
if [ $# -gt 0 ] && [ -f "$1" ]; then questions=$1; shift; fi
[ -f "$questions" ] || { echo "No file $questions" >&2; exit 1; }
only=" $* "
server=${MCP_SERVER:-metabase}
model=${CLAUDE_MODEL:-sonnet}
width=${WIDTH:-600}
rule=${ANSWER_RULE:-"Réponds en français, en donnant le chiffre, puis la requête SQL ou la question Metabase qui l'a produit."}

if [ "$again" = false ]; then
    command -v claude >/dev/null 2>&1 || { echo "No claude command: install Claude Code first." >&2; exit 1; }
    mb_healthy || { echo "Metabase does not answer on $mb_url: start the lab with ./setup/install.sh." >&2; exit 1; }
    mcp=()
    if [ -n "${MCP_CONFIG:-}" ]; then
        [ -f "$MCP_CONFIG" ] || { echo "No file $MCP_CONFIG (MCP_CONFIG)" >&2; exit 1; }
        mcp=(--strict-mcp-config --mcp-config "$MCP_CONFIG" --setting-sources "")
    fi
fi
out=work/claude
mkdir -p "$out"

# jsonl_sql FILE SQL: loads the lines of the stream FILE into the temporary table e (n, the
# order of the line; doc, the line as jsonb), runs SQL and prints the result.
jsonl_sql() {
    {
        echo '\set ON_ERROR_STOP on'
        echo 'create temp table e (n serial, doc jsonb);'
        echo 'copy e (doc) from stdin;'
        grep '^{' "$1" | tr -d '\r' | sed 's/\\/\\\\/g'
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
    start=$SECONDS
    if [ "$again" = true ]; then
        [ -f "$out/$id.jsonl" ] || { echo "== $id: no saved answer in $out"; failed=1; continue; }
        echo "== $id (saved answer): $question"
    else
        claude -p "$question $rule" --model "$model" "${mcp[@]}" --tools "" \
            --allowedTools "mcp__$server" --no-session-persistence \
            --output-format stream-json --verbose < /dev/null > "$out/$id.jsonl" 2> "$out/$id.err"
        echo "== $id ($((SECONDS - start)) s): $question"
    fi
    grep -q '"type":"result"' "$out/$id.jsonl" || {
        echo "   ERROR: no answer: $(head -c 300 "$out/$id.err" "$out/$id.jsonl" 2>/dev/null)"
        failed=1
        continue
    }
    jsonl_sql "$out/$id.jsonl" "
        with calls as (
            select e.n, c.ord, c.c->>'id' as call_id,
                   regexp_replace(c.c->>'name', '^mcp__[^_]+__', '') as tool,
                   c.c->>'name' as full_name, c.c->>'input' as input
              from e, jsonb_array_elements(e.doc->'message'->'content') with ordinality c(c, ord)
             where e.doc->>'type' = 'assistant' and c.c->>'type' = 'tool_use'),
        results as (
            select r->>'tool_use_id' as call_id, coalesce((r->>'is_error')::boolean, false) as is_error,
                   left(regexp_replace(case jsonb_typeof(r->'content') when 'string' then r->>'content'
                                            else (select string_agg(x->>'text', ' ') from jsonb_array_elements(r->'content') x) end,
                                       '\s+', ' ', 'g'), 160) as text
              from e, jsonb_array_elements(e.doc->'message'->'content') r
             where e.doc->>'type' = 'user' and jsonb_typeof(e.doc->'message'->'content') = 'array'
               and r->>'type' = 'tool_result'),
        dbs as (
            select distinct m[1]::int as id
              from calls, regexp_matches(input, '\"database(?:_id)?\": ?([0-9]+)', 'g') m),
        res as (select doc from e where doc->>'type' = 'result' order by n desc limit 1)
        select '   turns: ' || coalesce((select doc->>'num_turns' from res), '?')
               || ', tools: ' || coalesce((select string_agg(tool, ', ' order by n, ord) from calls), 'none')
        union all
        select '   databases: ' || coalesce((select string_agg(id::text, ', ' order by id) from dbs), 'none named')
        union all
        select '   failed call: ' || c.full_name || ': ' || coalesce(r.text, '')
          from calls c join results r using (call_id) where r.is_error
        union all
        select '   ERROR: ' || coalesce(doc->>'subtype', '') || ' ' || left(coalesce(doc->>'result', ''), 200)
          from res where coalesce((doc->>'is_error')::boolean, false)
        union all
        select '   answer: ' || left(regexp_replace(trim(coalesce(doc->>'result', '')), '\s+', ' ', 'g'), $width)
                 || case when length(regexp_replace(trim(coalesce(doc->>'result', '')), '\s+', ' ', 'g')) > $width
                         then ' […]' else '' end
          from res;" > "$out/$id.txt"
    cat "$out/$id.txt"
    grep -q '^   ERROR: ' "$out/$id.txt" && failed=1
done < "$questions"

[ "$asked" -gt 0 ] || { echo "No question asked: check the file and the ids given." >&2; exit 1; }
if [ "$failed" = 1 ]; then exit 2; fi
exit 0
