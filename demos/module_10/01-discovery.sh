#!/usr/bin/env bash
# Clip 10.1. What an MCP client finds before it is authorized: the MCP server of Metabase
# answers 401 without a token, and its WWW-Authenticate header names the metadata to read; the
# metadata names the authorization server, whose own metadata gives the endpoints of OAuth
# (registration, authorization, token, revocation) and the scopes. Every address there is
# built from the Site URL of Metabase (MB_SITE_URL in compose.yaml): if it is not the address
# your browser and Claude Code use, the authorization fails.
# No token and no key is used or shown. Usage: ./demos/module_10/01-discovery.sh
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
mb_healthy || { echo "Metabase does not answer on $mb_url: start the lab with ./setup/install.sh." >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. The MCP server, called without a token.
code=$(curl -sS -D "$tmp/headers.txt" -o "$tmp/body.json" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}' \
    "$mb_url/api/metabase-mcp")
echo "POST /api/metabase-mcp without a token: HTTP $code"
header=$(grep -i '^www-authenticate:' "$tmp/headers.txt" | tr -d '\r')
printf '%s\n' "$header" | sed 's/, /,\n    /g'
metadata=$(printf '%s' "$header" | sed -n 's/.*resource_metadata="\([^"]*\)".*/\1/p')
[ -n "$metadata" ] || { echo "No resource_metadata in the answer: is the MCP server on (Admin > AI > MCP)?" >&2; exit 2; }

# 2. The metadata of the protected resource, then of its authorization server.
curl -sS -o "$tmp/resource.json" "$metadata"
echo
echo "Resource metadata ($metadata):"
json_sql "$tmp/resource.json" "
    select '  resource: ' || (doc->>'resource') from j
    union all
    select '  authorization server: ' || s from j, jsonb_array_elements_text(doc->'authorization_servers') s"
issuer=$(json_sql "$tmp/resource.json" "select doc->'authorization_servers'->>0 from j")
curl -sS -o "$tmp/server.json" "$issuer/.well-known/oauth-authorization-server"
echo
echo "Authorization server ($issuer/.well-known/oauth-authorization-server):"
json_sql "$tmp/server.json" "
    select '  ' || k || ': ' || (doc->>k) from j,
           unnest(array['issuer', 'registration_endpoint', 'authorization_endpoint', 'token_endpoint', 'revocation_endpoint']) k
    union all
    select '  PKCE: ' || string_agg(m, ', ') from j, jsonb_array_elements_text(doc->'code_challenge_methods_supported') m"
echo
echo "Site URL of Metabase, as the browser must reach it: ${issuer}"
case "$issuer" in
    "$mb_url"|"http://localhost:$mbport") echo "It matches the address of the lab." ;;
    *) echo "It is not the address of the lab ($mb_url): set MB_SITE_URL to the address you use." ;;
esac
