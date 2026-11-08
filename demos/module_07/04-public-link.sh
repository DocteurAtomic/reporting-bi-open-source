#!/usr/bin/env bash
# Clip 7.4. The public link of a question: reads the setting enable-public-sharing (on by
# default in 0.65), makes the public link of "Paiements par mode" (POST /api/card/<id>/public_link,
# what Share > Create a public link does; the route POST /api/card/<id>/public_uuid does not
# exist), then opens it as a visitor without account: no key, no session
# (GET /api/public/card/<uuid>/query). The question lives in the collection "Facturation",
# closed to All Users in clip 7.2: the link shows it to anyone who has the address.
# Lists the public questions of the instance at the end (GET /api/card/public).
# With --remove, deletes the link instead (DELETE /api/card/<id>/public_link), and shows that
# the address no longer answers.
# Usage: ./demos/module_07/04-public-link.sh [--remove]
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
card=$(mb_card_id "Paiements par mode")
[ -n "$card" ] || { echo "No question \"Paiements par mode\": module 2 makes it." >&2; exit 1; }

if [ "${1:-}" = --remove ]; then
    mb_call GET "/api/card/$card" "$mb_tmp/card.json" >/dev/null
    uuid=$(json_sql "$mb_tmp/card.json" "select coalesce(doc->>'public_uuid', '') from j")
    code=$(mb_call DELETE "/api/card/$card/public_link" "$mb_tmp/out.json")
    echo "Public link of \"Paiements par mode\" deleted (HTTP $code)."
    [ -n "$uuid" ] && echo "The old address now answers HTTP $(curl -s -o /dev/null -w '%{http_code}' "$mb_url/api/public/card/$uuid/query")."
    exit 0
fi

mb_call GET /api/session/properties "$mb_tmp/props.json" >/dev/null
echo "enable-public-sharing: $(json_sql "$mb_tmp/props.json" "select doc->>'enable-public-sharing' from j")"
code=$(mb_call POST "/api/card/$card/public_link" "$mb_tmp/link.json")
[ "$code" = 200 ] || { echo "Metabase did not make the public link (HTTP $code): $(head -c 200 "$mb_tmp/link.json")" >&2; exit 1; }
uuid=$(json_sql "$mb_tmp/link.json" "select doc->>'uuid' from j")
echo "Public link: http://localhost:$mbport/public/question/$uuid"
code=$(curl -sS --max-time 60 -o "$mb_tmp/public.json" -w '%{http_code}' "$mb_url/api/public/card/$uuid/query")
echo "-- Opened without key nor session (HTTP $code):"
mb_rows "$mb_tmp/public.json"
mb_call GET /api/card/public "$mb_tmp/public-cards.json" >/dev/null
echo "-- Public questions of the instance:"
json_sql "$mb_tmp/public-cards.json" "select c->>'id' || ' | ' || (c->>'name') from j, jsonb_array_elements(doc) c order by (c->>'id')::int"
