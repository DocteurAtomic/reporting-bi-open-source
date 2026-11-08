#!/usr/bin/env bash
# Clip 9.5: what Metabot sends to the AI provider, as far as Metabase itself records it.
# Usage: ./demos/module_09/05-privacy.sh [--results on|off] [N]
#   Prints the setting metabot-query-execution-enabled? (Admin > AI > Allow Metabot to read
#   query results; on by default), then the last N conversations with Metabot (5 by default),
#   read in the application database of Metabase (tables metabot_conversation and
#   metabot_message of the database metabase): the question, the tokens sent to the model
#   (prompt) and received from it (completion), as Metabase counted them, and whether the
#   stored conversation holds rows of query results (a <data> block in the output of a tool),
#   which Metabase sent to the model.
#   --results off forbids Metabot to read the results of its queries; --results on allows it
#   again.
# The exact body of the requests to the provider is not read here: it would take a proxy
# between Metabase and the provider.
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ "${1:-}" = --results ]; then
    case "${2:-}" in on) v=true ;; off) v=false ;; *) echo "usage: $0 --results on|off [N]" >&2; exit 1 ;; esac
    printf '{"value":%s}\n' "$v" > "$tmp/value.json"
    code=$(mb_call PUT '/api/setting/metabot-query-execution-enabled%3F' "$tmp/out.json" "$tmp/value.json")
    [ "$code" = 204 ] || [ "$code" = 200 ] || { echo "Metabase refused the setting (HTTP $code)" >&2; exit 1; }
    shift 2
fi
n=${1:-5}
case "$n" in *[!0-9]*|'') echo "usage: $0 [--results on|off] [N]" >&2; exit 1 ;; esac

mb_call GET '/api/setting/metabot-query-execution-enabled%3F' "$tmp/setting.txt" >/dev/null
value=$(cat "$tmp/setting.txt")
echo "metabot-query-execution-enabled?: ${value:-true (default)}"

echo "Last $n conversations with Metabot (application database metabase):"
psql_lab -d metabase -At -F ' | ' <<SQL
select to_char(c.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC',
       left(coalesce((select u.data::jsonb->0->>'text' from metabot_message u
                       where u.conversation_id = c.id and u.role = 'user' order by u.id limit 1), '?'), 70),
       'prompt ' || coalesce(sum(((m.usage::jsonb) -> k ->> 'prompt')::int), 0),
       'completion ' || coalesce(sum(((m.usage::jsonb) -> k ->> 'completion')::int), 0),
       case when bool_or(m.data like '%<data>%') then 'result rows stored'
            when bool_or(m.data like '%<query_results%') then 'columns only, no rows'
            else 'no query result' end
  from (select * from metabot_conversation order by created_at desc limit $n) c
  join metabot_message m on m.conversation_id = c.id
  left join lateral jsonb_object_keys(case when m.usage is not null then m.usage::jsonb else '{}' end) k on true
 group by c.id, c.created_at
 order by c.created_at;
SQL
