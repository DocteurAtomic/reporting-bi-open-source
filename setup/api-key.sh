#!/usr/bin/env bash
# Creates an API key of Metabase in the Administrators group and writes it to .env, under
# MB_API_KEY, without printing it. ./setup/check.sh reads it to find and run your questions.
# Usage: ./setup/api-key.sh [--force]
#   It asks for the email and the password of the administrator account you created in the
#   browser (module 1), unless MB_ADMIN_EMAIL and MB_ADMIN_PASSWORD are set in the environment
#   or in .env. The password is never shown nor put on a command line.
#   When .env already holds a key that Metabase accepts, it does nothing; --force makes a new one.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
force=${1:-}

if ! mb_healthy; then
    echo "Metabase does not answer on $mb_url: start the lab with ./setup/install.sh." >&2
    exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

if [ -n "${MB_API_KEY:-}" ] && [ "$force" != --force ]; then
    if [ "$(mb_call GET /api/database "$tmp/out")" = 200 ]; then
        echo "The API key of .env is accepted by Metabase: nothing to do (--force makes a new one)."
        exit 0
    fi
    echo "The API key of .env is refused by Metabase: making a new one."
fi

email=${MB_ADMIN_EMAIL:-}
password=${MB_ADMIN_PASSWORD:-}
if [ -z "$email" ]; then read -rp "Email of the Metabase administrator: " email; fi
if [ -z "$password" ]; then read -rsp "Password: " password; echo; fi

# The session. The body holding the password is a file only this user can read.
printf '{"username":%s,"password":%s}' "$(json_text "$email")" "$(json_text "$password")" > "$tmp/login.json"
code=$(curl -sS --max-time 30 -o "$tmp/session.json" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' --data-binary "@$tmp/login.json" "$mb_url/api/session" || true)
rm -f "$tmp/login.json"
if [ "$code" != 200 ]; then
    echo "Metabase refused the login (HTTP $code): check the email and the password." >&2
    exit 1
fi
session=$(json_sql "$tmp/session.json" "select doc->>'id' from j")
rm -f "$tmp/session.json"
# session_call METHOD PATH OUTFILE [BODYFILE]: like mb_call, with the session instead of the key.
session_call() {
    local args=(-sS --max-time 30 -o "$3" -w '%{http_code}' -X "$1" -H 'Content-Type: application/json')
    if [ -n "${4:-}" ]; then args+=(--data-binary "@$4"); fi
    curl "${args[@]}" -H @<(printf 'X-Metabase-Session: %s\n' "$session") "$mb_url$2" 2>/dev/null || true
}

# The Administrators group: magic_group_type "admin" (its name follows the language).
code=$(session_call GET /api/permissions/group "$tmp/groups.json")
group=$(json_sql "$tmp/groups.json" "select g->>'id' from j, jsonb_array_elements(doc) g where g->>'magic_group_type' = 'admin'")
if [ "$code" != 200 ] || [ -z "$group" ]; then
    echo "The Administrators group was not found (HTTP $code): is this account an administrator?" >&2
    session_call DELETE /api/session "$tmp/out" >/dev/null
    exit 1
fi

name="check.sh $(date '+%Y-%m-%d %H:%M:%S')"
printf '{"name":%s,"group_id":%s}' "$(json_text "$name")" "$group" > "$tmp/key-request.json"
code=$(session_call POST /api/api-key "$tmp/key.json" "$tmp/key-request.json")
session_call DELETE /api/session "$tmp/out" >/dev/null
if [ "$code" != 200 ]; then
    echo "Metabase did not create the key (HTTP $code)." >&2
    exit 1
fi
key=$(json_sql "$tmp/key.json" "select doc->>'unmasked_key' from j")
rm -f "$tmp/key.json"
if [ -z "$key" ]; then
    echo "The answer of Metabase holds no key." >&2
    exit 1
fi

# .env gets the key in place of its MB_API_KEY line, or at its end. The key reaches awk
# through its environment.
umask 077
NEW_KEY=$key awk '
    /^MB_API_KEY=/ { print "MB_API_KEY=" ENVIRON["NEW_KEY"]; done = 1; next }
    { print }
    END { if (!done) print "MB_API_KEY=" ENVIRON["NEW_KEY"] }' .env > .env.new
mv .env.new .env
MB_API_KEY=$key
if [ "$(mb_call GET /api/database "$tmp/out")" = 200 ]; then
    echo "API key \"$name\" created in the Administrators group and written to .env (MB_API_KEY)."
else
    echo "The new key is written to .env but Metabase refuses it." >&2
    exit 1
fi
