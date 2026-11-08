# Sourced by the scripts of setup/. Moves to the root of the clone, loads .env (a variable
# already set in the environment wins), picks the container engine and the compose command,
# and defines the helpers of the scripts:
# - psql_lab runs psql as postgres inside the db container, through its local socket (trust
#   in the image's pg_hba.conf): no password is ever needed or shown;
# - mb_call calls the API of Metabase with the API key of .env, passed to curl through a file
#   descriptor and never on its command line;
# - json_sql reads a JSON document with the jsonb functions of PostgreSQL, in the container:
#   the scripts need neither jq nor any other tool on your machine besides bash and curl.
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%$'\r'}
        case "$line" in ''|'#'*) continue;; esac
        key=${line%%=*}; value=${line#*=}
        case "$key" in *[!A-Za-z0-9_]*|'') continue;; esac
        if [ -z "${!key+x}" ]; then export "$key=$value"; fi
    done < .env
fi
# Docker when it is installed, Podman otherwise; ENGINE and COMPOSE override the choice.
if [ -z "${ENGINE:-}" ]; then
    if command -v docker >/dev/null 2>&1; then ENGINE=docker; else ENGINE=podman; fi
fi
engine=$ENGINE
compose=${COMPOSE:-$engine compose}
c=${LAB_CONTAINER:-bicourse}
mbc=$c-metabase
port=${PGPORT:-5433}
mbport=${MBPORT:-3000}
mb_url=http://127.0.0.1:$mbport

# psql_lab [psql options] < script.sql
psql_lab() {
    $engine exec -i "$c" psql -U postgres -X "$@"
}

# Says whether a container is running (the db container by default).
lab_running() {
    [ "$($engine inspect -f '{{.State.Running}}' "${1:-$c}" 2>/dev/null)" = true ]
}

# Says whether Metabase answers {"status":"ok"} on /api/health.
mb_healthy() {
    curl -fsS --max-time 5 "$mb_url/api/health" 2>/dev/null | grep -q '"ok"'
}

# mb_call METHOD PATH OUTFILE [BODYFILE]
# Calls the API with the key MB_API_KEY, writes the body of the answer to OUTFILE and prints
# the HTTP status (000 when Metabase does not answer).
mb_call() {
    local method=$1 path=$2 out=$3 body=${4:-}
    local args=(-sS --max-time 120 -o "$out" -w '%{http_code}' -X "$method" -H 'Content-Type: application/json')
    if [ -n "$body" ]; then args+=(--data-binary "@$body"); fi
    curl "${args[@]}" -H @<(printf 'X-API-Key: %s\n' "${MB_API_KEY:-}") "$mb_url$path" 2>/dev/null || true
}

# json_sql FILE SQL
# Loads the JSON document of FILE into the temporary table j (one row, column doc jsonb), runs
# SQL on it and prints the result unaligned, without headers. The document is sent on the
# standard input of psql, as one line of COPY text (newlines and tabs between tokens dropped,
# backslashes doubled; JSON strings cannot hold a raw newline or tab).
json_sql() {
    {
        echo '\set ON_ERROR_STOP on'
        echo 'create temp table j (doc jsonb);'
        echo 'copy j from stdin;'
        tr -d '\n\r\t' < "$1" | sed 's/\\/\\\\/g'
        printf '\n\\.\n'
        printf '%s\n' "$2"
    } | psql_lab -d postgres -q -At
}

# sql_text 'value': the value as an SQL string literal.
sql_text() {
    printf "'%s'" "${1//\'/\'\'}"
}

# json_text 'value': the value as a JSON string (backslashes and double quotes escaped).
json_text() {
    local v=${1//\\/\\\\}
    v=${v//\"/\\\"}
    printf '"%s"' "$v"
}
