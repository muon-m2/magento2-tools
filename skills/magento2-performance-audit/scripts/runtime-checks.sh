#!/usr/bin/env bash
# runtime-checks.sh — runtime probes for indexer / cache / queue / DB.
#
# Inputs:
#   MAGENTO_CLI  (default: from .claude/.cache/magento2-context.json)
#   REDIS_CLI    (optional, default: redis-cli)
#
# Output: JSON ARRAY of finding objects (same schema as static-perf.sh), so that
# build-findings.sh can merge runtime results the same way it merges static ones.
# Probe raw text is attached to each finding's evidence/description so the LLM pass
# can interpret it. When a probe tool is absent, the array is empty (no findings) —
# build-findings.sh records "didn't run" separately via stderr.

set -uo pipefail

CONTEXT_FILE=".claude/.cache/magento2-context.json"
if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('magento_cli') or '')")"
fi

REDIS_CLI="${REDIS_CLI:-redis-cli}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "runtime-checks: python3 not found; cannot build findings" >&2
    echo "[]"
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
import sys

# Each probe that produced output becomes one finding carrying the raw probe text.
# Severity is intentionally `info` and confidence `candidate`: this is unparsed
# evidence the LLM pass must interpret and calibrate against the shared severity
# scale (see references/severity-perf.md). Probes whose tool was absent emit no
# finding; build-findings.sh reports that separately so "didn't run" is observable.
PROBES = [
    ('runtime-indexer', 'indexer', 'IDX_OUT',
     'Indexer status snapshot (interpret manually)',
     '`{magento_cli} indexer:status` output. Flag any index in "invalid" or '
     'stuck "processing"; recommend reindex and review update mode.'),
    ('runtime-cache', 'cache', 'CACHE_OUT',
     'Cache type status snapshot (interpret manually)',
     '`{magento_cli} cache:status` output. Flag disabled cache types that should '
     'be enabled in production (full_page, block_html, config).'),
    ('runtime-queue', 'queue', 'QUEUE_OUT',
     'Queue consumers snapshot (interpret manually)',
     '`{magento_cli} queue:consumers:list` output. Cross-check against declared '
     'queue_consumer.xml consumers; flag declared-but-unregistered consumers.'),
    ('runtime-redis', 'cache', 'REDIS_OUT',
     'Redis stats snapshot (interpret manually)',
     '`redis-cli INFO stats` output. Compute keyspace_hits / (hits+misses); flag '
     'a low hit ratio on a warm cache.'),
]

out = []
fid = 1
for pid, category, env_key, title, recommendation in PROBES:
    raw = os.environ.get(env_key, '')
    lines = raw.splitlines()[-30:]
    if not lines:
        # Tool absent or probe produced nothing — not a finding. Note on stderr so a
        # caller can tell an empty probe ("didn't run") from a clean probe ("found
        # nothing"). build-findings.sh aggregates these into scanner_errors.
        print(f'{pid}: no output (probe tool unavailable or returned nothing)',
              file=sys.stderr)
        continue
    out.append({
        'id': f'perf-audit-runtime-{fid:03d}',
        'severity': 'info',
        'confidence': 'candidate',
        'category': category,
        'subcategory': pid,
        'title': title,
        'description': '\n'.join(lines),
        'evidence': [{'file': '(runtime probe)', 'line': 0,
                      'snippet': (lines[-1] if lines else '')[:200]}],
        'recommendation': recommendation,
        'verification': 'Re-run runtime-checks.sh after remediation; the probe '
                        'snapshot should reflect the corrected state.'
    })
    fid += 1

print(json.dumps(out, indent=2))
PY
