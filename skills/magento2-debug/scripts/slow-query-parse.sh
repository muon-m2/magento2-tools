#!/usr/bin/env bash
# slow-query-parse.sh — parse MySQL slow log, group by signature.
#
# Usage:
#   slow-query-parse.sh <slow-log-path>

set -uo pipefail

LOG="${1:?usage: slow-query-parse.sh <slow-log-path>}"
[ -f "$LOG" ] || { echo "slow-query-parse: file not found: $LOG" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "slow-query-parse: python3 required" >&2
    exit 3
fi

python3 - "$LOG" <<'PY'
import json
import re
import sys
from collections import defaultdict

path = sys.argv[1]

queries = []  # (query_time, query_text)
current = []
qtime = 0.0

with open(path, encoding='utf-8', errors='replace') as fh:
    for line in fh:
        if line.startswith('# Query_time'):
            m = re.search(r'Query_time:\s*([0-9.]+)', line)
            if m:
                qtime = float(m.group(1))
        elif line.startswith('#'):
            continue
        elif line.strip().lower().startswith(('use ', 'set timestamp', '--')):
            continue
        elif line.strip().endswith(';'):
            current.append(line.strip())
            text = ' '.join(current)
            queries.append((qtime, text))
            current = []
            qtime = 0.0
        else:
            current.append(line.strip())


def signature(q: str) -> str:
    s = re.sub(r"'[^']*'", "?", q)
    s = re.sub(r"\b\d+\b", "?", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:300]


groups = defaultdict(lambda: {'count': 0, 'total_time': 0.0, 'max_time': 0.0, 'sample': ''})

for qtime, text in queries:
    sig = signature(text)
    g = groups[sig]
    g['count'] += 1
    g['total_time'] += qtime
    g['max_time'] = max(g['max_time'], qtime)
    if not g['sample']:
        g['sample'] = text[:500]

top = sorted(groups.items(), key=lambda kv: kv[1]['total_time'], reverse=True)[:20]

out = {
    'total_distinct_queries': len(groups),
    'total_logged': len(queries),
    'top_20_by_total_time': [
        {
            'signature': sig,
            'count': g['count'],
            'total_time_seconds': round(g['total_time'], 3),
            'avg_time_seconds': round(g['total_time'] / g['count'], 3) if g['count'] else 0,
            'max_time_seconds': round(g['max_time'], 3),
            'sample': g['sample'],
        }
        for sig, g in top
    ],
}
print(json.dumps(out, indent=2))
PY
