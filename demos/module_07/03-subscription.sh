#!/usr/bin/env bash
# Clip 7.3. The subscription of the direction to "Tableau de bord de la facturation" (module 5):
# by mail to direction@pachadata.example (the account of 02-collections.sh), every Monday at
# 8:00 (POST /api/pulse), made if the dashboard has none for that address. Then sends it at
# once, as the button "Send now" does (POST /api/pulse/test), and prints what Mailpit received:
# the subject, the sender, and the lines of the mail that hold the numbers of the dashboard.
# The open-source edition sends the dashboard with the default values of its filters (the
# filter "Période" has none: every year); a value per subscription is a paid feature. The mail
# shows what the creator of the subscription can see, even to a recipient who cannot open the
# collection "Facturation".
# Usage: ./demos/module_07/03-subscription.sh (after 03-mail.sh)
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh
mail_url=http://127.0.0.1:${MAILPORT:-8025}
name="Tableau de bord de la facturation"

mb_call GET /api/dashboard "$mb_tmp/dashboards.json" >/dev/null
dash=$(json_sql "$mb_tmp/dashboards.json" "
    select max((d->>'id')::int) from j, jsonb_array_elements(doc) d
     where d->>'name' = $(sql_text "$name") and not coalesce((d->>'archived')::boolean, false)")
[ -n "$dash" ] || { echo "No dashboard named \"$name\": module 5 makes it (demos/module_05/01-dashboard.sh)." >&2; exit 1; }
mb_call GET "/api/user?query=direction%40pachadata.example" "$mb_tmp/users.json" >/dev/null
u=$(json_sql "$mb_tmp/users.json" "select u->>'id' from j, jsonb_array_elements(doc->'data') u where u->>'email' = 'direction@pachadata.example'")
[ -n "$u" ] || { echo "No account direction@pachadata.example: run 02-collections.sh first." >&2; exit 1; }
mb_call GET "/api/dashboard/$dash" "$mb_tmp/dash.json" >/dev/null

# The body: every card of the dashboard that runs a question, the channel, the schedule.
json_sql "$mb_tmp/dash.json" "
    select jsonb_build_object(
             'name', doc->>'name', 'dashboard_id', (doc->>'id')::int, 'skip_if_empty', false,
             'cards', (select jsonb_agg(jsonb_build_object('id', (dc->>'card_id')::int, 'dashboard_card_id', (dc->>'id')::int,
                                                           'include_csv', false, 'include_xls', false)
                                        order by (dc->>'row')::int, (dc->>'col')::int)
                         from jsonb_array_elements(doc->'dashcards') dc where dc->>'card_id' is not null),
             'channels', jsonb_build_array(jsonb_build_object(
                 'channel_type', 'email', 'enabled', true,
                 'recipients', jsonb_build_array(jsonb_build_object('id', $u, 'email', 'direction@pachadata.example')),
                 'schedule_type', 'weekly', 'schedule_day', 'mon', 'schedule_hour', 8, 'schedule_frame', null)))
      from j" > "$mb_tmp/pulse.json"
mb_call GET "/api/pulse?dashboard_id=$dash" "$mb_tmp/pulses.json" >/dev/null
existing=$(json_sql "$mb_tmp/pulses.json" "
    select min((p->>'id')::int) from j, jsonb_array_elements(doc) p, jsonb_array_elements(p->'channels') ch,
           jsonb_array_elements(ch->'recipients') r
     where not coalesce((p->>'archived')::boolean, false) and r->>'email' = 'direction@pachadata.example'")
if [ -z "$existing" ]; then
    code=$(mb_call POST /api/pulse "$mb_tmp/pulse-new.json" "$mb_tmp/pulse.json")
    [ "$code" = 200 ] || { echo "Metabase did not save the subscription (HTTP $code): $(head -c 300 "$mb_tmp/pulse-new.json")" >&2; exit 1; }
    existing=$(json_sql "$mb_tmp/pulse-new.json" "select doc->>'id' from j")
    echo "Subscription $existing saved: \"$name\" to direction@pachadata.example, weekly, Monday 8:00."
else
    echo "Subscription $existing already there for direction@pachadata.example."
fi

curl -fsS "$mail_url/api/v1/messages" -o "$mb_tmp/before.json" \
    || { echo "Mailpit does not answer on $mail_url (03-mail.sh)." >&2; exit 1; }
before=$(json_sql "$mb_tmp/before.json" "select doc->>'total' from j")
code=$(mb_call POST /api/pulse/test "$mb_tmp/out.json" "$mb_tmp/pulse.json")
[ "$code" = 200 ] || { echo "Metabase did not send the subscription (HTTP $code)" >&2; exit 1; }
for _ in $(seq 1 30); do
    curl -fsS "$mail_url/api/v1/messages" -o "$mb_tmp/after.json"
    [ "$(json_sql "$mb_tmp/after.json" "select doc->>'total' from j")" -gt "$before" ] && break
    sleep 1
done
id=$(json_sql "$mb_tmp/after.json" "select doc->'messages'->0->>'ID' from j")
curl -fsS "$mail_url/api/v1/message/$id" -o "$mb_tmp/message.json"
json_sql "$mb_tmp/message.json" "
    select format('Subject: %s%sFrom: %s <%s>%sRecipients (To and Bcc): %s', doc->>'Subject', E'\n', doc->'From'->>'Name', doc->'From'->>'Address', E'\n',
                  (select string_agg(t->>'Address', ', ') from jsonb_array_elements(coalesce(doc->'To', '[]') || coalesce(doc->'Bcc', '[]')) t))
      from j"
json_sql "$mb_tmp/message.json" "select format('Charts drawn as images in the mail: %s', jsonb_array_length(coalesce(doc->'Inline', '[]'))) from j"
echo "-- The numbers in the text of the mail:"
json_sql "$mb_tmp/message.json" "select doc->>'Text' from j" \
    | grep -E '^(Sent by|Showing|Typepaiement|mois|Factures sans)|décembre 1, 2011|janvier 1, 2012' || true
