#!/usr/bin/env bash
# Clip 9.1: the AI provider of Metabot and its model, read through the API.
# Usage: ./demos/module_09/01-provider.sh [--model ID]
#   Without argument, prints the providers Metabase knows (where their key comes from, whether
#   they are usable; the key itself is never printed), the model chosen for Metabot
#   (llm-metabot-provider), whether Metabot is configured (llm-metabot-configured?), and the
#   number of models the provider offers.
#   --model ID chooses the model of Metabot, as Admin > AI > Models does, such as
#   --model openrouter/anthropic/claude-sonnet-4.6 (an id of GET /api/llm/models, prefixed by
#   the key of its provider).
# The key goes in .env (MB_LLM_OPENROUTER_API_KEY), then: docker compose up -d metabase. A
# restart does not read .env again: the environment of a container is fixed when it is created.
set -uo pipefail
. "$(dirname "$0")/../../setup/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ "${1:-}" = --model ]; then
    [ -n "${2:-}" ] || { echo "usage: $0 --model PROVIDER/MODEL" >&2; exit 1; }
    printf '{"value":%s}\n' "$(json_text "$2")" > "$tmp/value.json"
    code=$(mb_call PUT /api/setting/llm-metabot-provider "$tmp/out.json" "$tmp/value.json")
    [ "$code" = 204 ] || [ "$code" = 200 ] || { echo "Metabase refused the model (HTTP $code): $(head -c 300 "$tmp/out.json")" >&2; exit 1; }
    echo "Model of Metabot set to $2"
fi

code=$(mb_call GET /api/llm/providers "$tmp/providers.json")
[ "$code" = 200 ] || { echo "GET /api/llm/providers: HTTP $code; check the lab with ./setup/check.sh 00" >&2; exit 1; }
echo "Providers (GET /api/llm/providers):"
json_sql "$tmp/providers.json" "
    select format('  %s: source %s, usable %s, key %s, set by %s', p->>'key', p->>'source', p->>'usable',
                  case when coalesce(p->'config'->>'api-key', '') = '' then 'absent'
                       when p->'config'->>'api-key' like '%*%' then 'present, masked by Metabase'
                       else 'present' end,
                  coalesce((select string_agg(v, ', ') from jsonb_array_elements_text(p->'env_vars') v), '-'))
      from j, jsonb_array_elements(doc) p"
[ "$(json_sql "$tmp/providers.json" "select jsonb_array_length(doc) from j")" = 0 ] \
    && echo "  none: put the key in .env, then docker compose up -d metabase"

for key in llm-metabot-provider 'llm-metabot-configured%3F'; do
    mb_call GET "/api/setting/$key" "$tmp/setting.txt" >/dev/null
    value=$(cat "$tmp/setting.txt")
    printf '%s: %s\n' "${key/\%3F/?}" "${value:-(not set)}"
done
mb_call GET /api/llm/models "$tmp/models.json" >/dev/null
json_sql "$tmp/models.json" "
    select format('Models offered: %s by %s', jsonb_array_length(p->'models'), p->>'name')
      from j, jsonb_array_elements(doc) p"
