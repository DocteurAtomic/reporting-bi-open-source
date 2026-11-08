#!/usr/bin/env bash
# Clip 7.3. The alert of the invoicing service: the question "Factures sans paiement de 2011
# par mois" (03-unpaid-by-month.json, in the collection "Facturation", made or replaced), a bar
# chart with a goal line at 500, and an alert on it (POST /api/notification) that mails
# facturation@pachadata.example every Monday at 8:00 when the bars go above the goal. Made if
# the question has no alert yet. Then sends it at once (POST /api/notification/<id>/send), and
# prints the subject Mailpit received; with a goal above every bar, Metabase skips the mail.
# Usage: ./demos/module_07/03-alert.sh [GOAL] (after 03-mail.sh; 500 when no GOAL is given)
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
d=demos/module_07
mail_url=http://127.0.0.1:${MAILPORT:-8025}
goal=${1:-500}
[[ "$goal" =~ ^[0-9]+$ ]] || { echo "usage: $0 [GOAL]" >&2; exit 1; }

coll=$(mb_collection Facturation)
json_sql "$d/03-unpaid-by-month.json" "select jsonb_set(doc, '{visualization_settings,graph.goal_value}', to_jsonb($goal)) from j" > "$mb_tmp/card.json"
card=$(mb_save_card "$mb_tmp/card.json" "$coll")
mb_run_card "$card" "$mb_tmp/answer.json"
echo "\"Factures sans paiement de 2011 par mois\" (id $card), goal $goal:"
mb_rows "$mb_tmp/answer.json"

mb_call GET "/api/user?query=facturation%40pachadata.example" "$mb_tmp/users.json" >/dev/null
u=$(json_sql "$mb_tmp/users.json" "select u->>'id' from j, jsonb_array_elements(doc->'data') u where u->>'email' = 'facturation@pachadata.example'")
[ -n "$u" ] || { echo "No account facturation@pachadata.example: run 01-groups.sh first." >&2; exit 1; }
mb_call GET "/api/notification?card_id=$card" "$mb_tmp/notifications.json" >/dev/null
alert=$(json_sql "$mb_tmp/notifications.json" "
    select min((n->>'id')::int) from j, jsonb_array_elements(doc) n
     where n->>'payload_type' = 'notification/card' and (n->'payload'->>'card_id')::int = $card and coalesce((n->>'active')::boolean, true)")
if [ -z "$alert" ]; then
    printf '{"payload_type":"notification/card","payload":{"card_id":%s,"send_condition":"goal_above","send_once":false},"handlers":[{"channel_type":"channel/email","recipients":[{"type":"notification-recipient/user","user_id":%s}]}],"subscriptions":[{"type":"notification-subscription/cron","cron_schedule":"0 0 8 ? * MON *"}]}' \
        "$card" "$u" > "$mb_tmp/alert.json"
    code=$(mb_call POST /api/notification "$mb_tmp/alert-new.json" "$mb_tmp/alert.json")
    [ "$code" = 200 ] || { echo "Metabase did not save the alert (HTTP $code): $(head -c 300 "$mb_tmp/alert-new.json")" >&2; exit 1; }
    alert=$(json_sql "$mb_tmp/alert-new.json" "select doc->>'id' from j")
    echo "Alert $alert saved: above the goal, to facturation@pachadata.example, Monday 8:00."
else
    echo "Alert $alert already there on the question."
fi

curl -fsS "$mail_url/api/v1/messages" -o "$mb_tmp/before.json" \
    || { echo "Mailpit does not answer on $mail_url (03-mail.sh)." >&2; exit 1; }
before=$(json_sql "$mb_tmp/before.json" "select doc->>'total' from j")
code=$(mb_call POST "/api/notification/$alert/send" "$mb_tmp/out.json")
[ "$code" = 204 ] || { echo "Metabase did not send the alert (HTTP $code)" >&2; exit 1; }
got=
for _ in $(seq 1 10); do
    sleep 1
    curl -fsS "$mail_url/api/v1/messages" -o "$mb_tmp/after.json"
    if [ "$(json_sql "$mb_tmp/after.json" "select doc->>'total' from j")" -gt "$before" ]; then got=1; break; fi
done
if [ -n "$got" ]; then
    echo "Mail received: $(json_sql "$mb_tmp/after.json" "select doc->'messages'->0->>'Subject' from j")"
else
    echo "No mail after 10 seconds: no bar above $goal, Metabase skipped the alert."
fi
