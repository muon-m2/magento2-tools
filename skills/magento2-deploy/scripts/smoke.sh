#!/usr/bin/env bash
# smoke.sh — run smoke tests after a deploy.
#
# Inputs:
#   MODULES       space-separated module list
#   BASE_URL      http://... (default: from env or http://localhost)
#   MAGENTO_CLI   (default: from .claude/.cache/magento2-context.json)
#   OUTPUT_FILE   where to write JSON summary
#
# Output:
#   JSON summary of smoke results (also to OUTPUT_FILE when set).

set -uo pipefail

MODULES="${MODULES:?MODULES is required}"
BASE_URL="${BASE_URL:-http://localhost}"
CONTEXT_FILE=".claude/.cache/magento2-context.json"

if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('magento_cli') or '')")"
fi

declare -a RESULTS

record() {
    local name="$1" result="$2" detail="$3"
    RESULTS+=("$(printf '{"name":"%s","result":"%s","detail":"%s"}' "$name" "$result" "${detail//\"/\\\"}")")
}

# Module status — every deployed module must appear individually in the ENABLED list.
# `module:status` (no flag) prints BOTH the enabled and disabled sections, so a disabled
# module still matched the old alternation; and the alternation passed if ANY one module
# matched, not all. `--enabled` lists only enabled module names, one per line, so an exact
# whole-line match per module is both disabled-safe and all-modules-required.
if [ -n "${MAGENTO_CLI:-}" ]; then
    enabled_list="$(eval "$MAGENTO_CLI module:status --enabled" 2>&1)"
    missing=""
    for mod in $MODULES; do
        printf '%s\n' "$enabled_list" | grep -qx "$mod" || missing="${missing:+$missing }$mod"
    done
    if [ -z "$missing" ]; then
        record "module-status" "pass" "all deployed modules listed as enabled"
    else
        record "module-status" "fail" "not in enabled list: $missing"
    fi

    if eval "$MAGENTO_CLI setup:db:status" 2>&1 | grep -qi "up to date"; then
        record "db-status" "pass" "schema up to date"
    else
        record "db-status" "fail" "schema not up to date"
    fi
else
    record "module-status" "skipped" "magento_cli not available"
    record "db-status" "skipped" "magento_cli not available"
fi

# Admin reachable (302)
if command -v curl >/dev/null 2>&1; then
    code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/admin/" 2>/dev/null || echo 000)"
    case "$code" in
        200|302|301) record "admin-ui" "pass" "HTTP $code" ;;
        *) record "admin-ui" "fail" "HTTP $code" ;;
    esac

    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/graphql" \
        -H 'Content-Type: application/json' \
        -d '{"query":"query{__schema{queryType{name}}}"}' 2>/dev/null || echo 000)"
    case "$code" in
        200) record "graphql" "pass" "HTTP 200" ;;
        000) record "graphql" "skipped" "graphql endpoint unreachable" ;;
        *) record "graphql" "fail" "HTTP $code" ;;
    esac
else
    record "http-checks" "skipped" "curl not available"
fi

joined="$(IFS=','; echo "${RESULTS[*]}")"
json=$(printf '{"smoke":{"base_url":"%s","results":[%s]}}' "$BASE_URL" "$joined")
echo "$json"
if [ -n "${OUTPUT_FILE:-}" ]; then
    echo "$json" > "$OUTPUT_FILE"
fi
