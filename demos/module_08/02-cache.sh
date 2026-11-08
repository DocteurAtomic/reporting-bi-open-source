#!/usr/bin/env bash
# Clip 8.2. The default caching policy of Metabase (Admin > Performance > Database caching >
# Default policy), read and set through the API, and the card "Visites et visiteurs par mois"
# run to see whether its answer comes from the cache. The free edition has this one policy, for
# the whole instance: "Adaptive" (strategy ttl in the API: the answer is kept for the average
# time of the query multiplied by the multiplier, when that average is above the minimum query
# duration) or "Don't cache results" (nocache). Duration, schedule and a policy by database,
# dashboard or question are kept for the paid editions.
# Usage: ./demos/module_08/02-cache.sh policy             prints the default policy
#        ./demos/module_08/02-cache.sh adaptive [M] [S]   sets "Adaptive", multiplier M (10),
#                                                         minimum query duration S seconds (1)
#        ./demos/module_08/02-cache.sh none               sets "Don't cache results"
#        ./demos/module_08/02-cache.sh reset              removes the default policy, as on a new
#                                                         install: nothing is cached
#        ./demos/module_08/02-cache.sh run                runs the card, prints its time, the
#                                                         time its cached answer was stored
#                                                         (none when PostgreSQL answered) and
#                                                         the row of December 2020
set -euo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
. setup/mbql.sh

policy() {
    mb_call GET "/api/cache?model=root" "$mb_tmp/cache.json" >/dev/null
    json_sql "$mb_tmp/cache.json" "
        select coalesce((select 'default policy: ' || (c->'strategy')::text
                           from jsonb_array_elements(doc->'data') c where c->>'model' = 'root'),
                        'default policy: none set')
          from j"
}

case "${1:-}" in
    policy) policy ;;
    adaptive)
        printf '{"model":"root","model_id":0,"strategy":{"type":"ttl","multiplier":%d,"min_duration_ms":%d}}\n' \
            "${2:-10}" "$(( ${3:-1} * 1000 ))" > "$mb_tmp/body.json"
        code=$(mb_call PUT /api/cache "$mb_tmp/answer.json" "$mb_tmp/body.json")
        [ "$code" = 200 ] || { echo "Metabase refused the policy (HTTP $code): $(cat "$mb_tmp/answer.json")" >&2; exit 1; }
        policy ;;
    none)
        echo '{"model":"root","model_id":0,"strategy":{"type":"nocache"}}' > "$mb_tmp/body.json"
        code=$(mb_call PUT /api/cache "$mb_tmp/answer.json" "$mb_tmp/body.json")
        [ "$code" = 200 ] || { echo "Metabase refused the policy (HTTP $code): $(cat "$mb_tmp/answer.json")" >&2; exit 1; }
        policy ;;
    reset)
        echo '{"model":"root","model_id":[0]}' > "$mb_tmp/body.json"
        code=$(mb_call DELETE /api/cache "$mb_tmp/answer.json" "$mb_tmp/body.json")
        [ "$code" = 204 ] || { echo "Metabase refused to remove the policy (HTTP $code): $(cat "$mb_tmp/answer.json")" >&2; exit 1; }
        policy ;;
    run)
        id=$(mb_card_id "Visites et visiteurs par mois")
        [ -n "$id" ] || { echo "No question \"Visites et visiteurs par mois\": run 01-dashboard.sh first." >&2; exit 2; }
        start=$(date +%s%N)
        mb_run_card "$id" "$mb_tmp/answer.json"
        elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
        json_sql "$mb_tmp/answer.json" "
            select format('%s: answered in %s ms (running_time %s ms), cached at: %s, December 2020: %s visits, %s visitors',
                          to_char(now(), 'HH24:MI:SS'), $elapsed, doc->>'running_time', coalesce(doc->>'cached', '(not from the cache)'),
                          r->>1, r->>2)
              from j, jsonb_array_elements(doc->'data'->'rows') r
             where r->>0 like '2020-12-01%'" ;;
    *) echo "usage: $0 policy | adaptive [multiplier] [minimum seconds] | none | reset | run" >&2; exit 1 ;;
esac
