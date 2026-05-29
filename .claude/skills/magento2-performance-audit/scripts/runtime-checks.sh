#!/usr/bin/env bash
# runtime-checks.sh — runtime probes for indexer / cache / queue / DB.
#
# Inputs:
#   MAGENTO_CLI  (default: from .claude/.cache/magento2-context.json)
#   REDIS_CLI    (optional, default: redis-cli)
#
# Output: JSON document with per-check results.

set -uo pipefail

CONTEXT_FILE=".claude/.cache/magento2-context.json"
if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('magento_cli') or '')")"
fi

REDIS_CLI="${REDIS_CLI:-redis-cli}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "{}"
    exit 2
fi

# Indexer status
IDX_OUT=""
if [ -n "${MAGENTO_CLI:-}" ]; then
    IDX_OUT="$(eval "$MAGENTO_CLI indexer:status" 2>/dev/null || true)"
fi

CACHE_OUT=""
if [ -n "${MAGENTO_CLI:-}" ]; then
    CACHE_OUT="$(eval "$MAGENTO_CLI cache:status" 2>/dev/null || true)"
fi

QUEUE_OUT=""
if [ -n "${MAGENTO_CLI:-}" ]; then
    QUEUE_OUT="$(eval "$MAGENTO_CLI queue:consumers:list" 2>/dev/null || true)"
fi

REDIS_OUT=""
if command -v "$REDIS_CLI" >/dev/null 2>&1; then
    REDIS_OUT="$($REDIS_CLI INFO stats 2>/dev/null | head -c 2000 || true)"
fi

IDX_OUT="$IDX_OUT" CACHE_OUT="$CACHE_OUT" QUEUE_OUT="$QUEUE_OUT" REDIS_OUT="$REDIS_OUT" python3 <<'PY'
import json
import os

out = {
    'indexer_status_raw': os.environ.get('IDX_OUT', '').splitlines()[-30:],
    'cache_status_raw': os.environ.get('CACHE_OUT', '').splitlines()[-30:],
    'queue_consumers_raw': os.environ.get('QUEUE_OUT', '').splitlines()[-30:],
    'redis_stats_raw': os.environ.get('REDIS_OUT', '').splitlines()[-30:],
    'available': {
        'magento_cli': bool(os.environ.get('IDX_OUT') or os.environ.get('CACHE_OUT')),
        'redis_cli': bool(os.environ.get('REDIS_OUT')),
    }
}

print(json.dumps(out, indent=2))
PY
