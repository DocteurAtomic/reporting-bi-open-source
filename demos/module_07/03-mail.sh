#!/usr/bin/env bash
# Clip 7.3. Points Metabase to the test mail server of the lab, Mailpit (compose profile mail):
# host mailpit, port 1025, no TLS, no account (PUT /api/email, what Administration >
# Settings > Email saves), and the sender PachaData Formation <reporting@pachadata.example>.
# Then asks Mailpit how many mails it holds. Nothing leaves your machine: Mailpit keeps every
# mail and shows it on http://localhost:8025 (MAILPORT in .env).
# Usage: docker compose --profile mail up -d mailpit, then ./demos/module_07/03-mail.sh
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mail_url=http://127.0.0.1:${MAILPORT:-8025}
curl -fsS --max-time 5 "$mail_url/api/v1/info" -o "$tmp/info.json" 2>/dev/null \
    || { echo "Mailpit does not answer on $mail_url: start it with: $compose --profile mail up -d mailpit" >&2; exit 1; }
echo "Mailpit $(json_sql "$tmp/info.json" "select doc->>'Version' from j") answers on $mail_url."

echo '{"email-smtp-host":"mailpit","email-smtp-port":1025,"email-smtp-security":"none","email-smtp-username":null,"email-smtp-password":null}' > "$tmp/email.json"
code=$(mb_call PUT /api/email "$tmp/out.json" "$tmp/email.json")
[ "$code" = 200 ] || { echo "Metabase refused the mail settings (HTTP $code): $(head -c 300 "$tmp/out.json")" >&2; exit 1; }
for kv in 'email-from-address|"reporting@pachadata.example"' 'email-from-name|"PachaData Formation"'; do
    printf '{"value":%s}' "${kv#*|}" > "$tmp/value.json"
    code=$(mb_call PUT "/api/setting/${kv%%|*}" "$tmp/out.json" "$tmp/value.json")
    [ "$code" = 204 ] || { echo "Metabase refused ${kv%%|*} (HTTP $code)" >&2; exit 1; }
done
mb_call GET /api/session/properties "$tmp/props.json" >/dev/null
echo "Metabase sends mail through mailpit:1025, from PachaData Formation <reporting@pachadata.example>; email-configured?: $(json_sql "$tmp/props.json" "select doc->>'email-configured?' from j")."
curl -fsS "$mail_url/api/v1/messages" -o "$tmp/messages.json"
echo "Mails in Mailpit: $(json_sql "$tmp/messages.json" "select doc->>'total' from j")."
