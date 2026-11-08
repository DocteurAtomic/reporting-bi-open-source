#!/usr/bin/env bash
# Clip 7.4. A guest embed, the way a web page of your own would show a question of Metabase
# (what the documentation of 0.65 calls guest embedding; the former static embedding):
# 1. turns embedding on (setting enable-embedding-simple, Embedding hub > Security >
#    Enable embedding) and publishes the question "Factures sans paiement de 2011 par mois"
#    (03-alert.sh) for embedding (enable_embedding on the question);
# 2. signs a JWT as your server would: {"resource":{"question":ID},"params":{},"exp":...},
#    HS256 with the embedding secret key of Metabase, read by the API and never printed, by
#    openssl (no other tool);
# 3. asks Metabase for the rows with that token alone (GET /api/embed/card/<jwt>/query), then
#    with a token whose signature is wrong.
# The secret signs every embed of the instance: it stays on the server, never in a page.
# Usage: ./demos/module_07/04-guest-embed.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
chmod 700 "$mb_tmp"
card=$(mb_card_id "Factures sans paiement de 2011 par mois")
[ -n "$card" ] || { echo "No question \"Factures sans paiement de 2011 par mois\": run 03-alert.sh first." >&2; exit 1; }
echo '{"value":true}' > "$mb_tmp/on.json"
code=$(mb_call PUT /api/setting/enable-embedding-simple "$mb_tmp/out.json" "$mb_tmp/on.json")
[ "$code" = 204 ] || { echo "Metabase refused to turn embedding on (HTTP $code)" >&2; exit 1; }
echo '{"enable_embedding":true,"embedding_params":{}}' > "$mb_tmp/publish.json"
code=$(mb_call PUT "/api/card/$card" "$mb_tmp/out.json" "$mb_tmp/publish.json")
[ "$code" = 200 ] || { echo "Metabase did not publish the question for embedding (HTTP $code)" >&2; exit 1; }
echo "Embedding on; \"Factures sans paiement de 2011 par mois\" (id $card) published for embedding."

mb_call GET /api/setting/embedding-secret-key "$mb_tmp/secret.json" >/dev/null
secret=$(tr -d '"\n' < "$mb_tmp/secret.json")
rm -f "$mb_tmp/secret.json"
[ -n "$secret" ] || { echo "No embedding secret key in Metabase." >&2; exit 1; }
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
payload=$(printf '{"resource":{"question":%s},"params":{},"exp":%s}' "$card" "$(( $(date +%s) + 600 ))" | b64url)
signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -mac HMAC -macopt "key:$secret" -binary | b64url)
unset secret
code=$(curl -sS --max-time 60 -o "$mb_tmp/embed.json" -w '%{http_code}' "$mb_url/api/embed/card/$header.$payload.$signature/query" || true)
echo "-- With the signed token alone (HTTP $code), the embed page being http://localhost:$mbport/embed/question/<jwt>:"
mb_rows "$mb_tmp/embed.json"
code=$(curl -sS --max-time 60 -o "$mb_tmp/bad.txt" -w '%{http_code}' "$mb_url/api/embed/card/$header.$payload.AAAA/query" || true)
echo "-- With a wrong signature: HTTP $code, $(head -c 200 "$mb_tmp/bad.txt")"
