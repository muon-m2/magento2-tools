#!/usr/bin/env bash
# log-triage.sh — group log entries by signature, top 20 by count.
#
# Usage:
#   log-triage.sh <log-file> [<pattern>]

set -uo pipefail

LOG_FILE="${1:?usage: log-triage.sh <log-file> [<pattern>]}"
PATTERN="${2:-}"

[ -f "$LOG_FILE" ] || { echo "log-triage: file not found: $LOG_FILE" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "log-triage: python3 required" >&2
    exit 3
fi

python3 - "$LOG_FILE" "$PATTERN" <<'PY'
import json
import re
import sys
from collections import defaultdict

path, pattern = sys.argv[1], sys.argv[2]

groups = defaultdict(lambda: {'count': 0, 'first': None, 'last': None, 'sample': ''})

# Normalize: replace numbers, paths, IDs with placeholders to compute signature.
def signature(line: str) -> str:
    s = re.sub(r'[0-9a-f]{8,}', 'HEX', line)
    s = re.sub(r'\d{2,}', 'N', s)
    s = re.sub(r'/\S+', '/PATH', s)
    s = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'EMAIL', s)
    return s[:200]

with open(path, encoding='utf-8', errors='replace') as fh:
    for line in fh:
        if pattern and pattern not in line:
            continue
        sig = signature(line.strip())
        entry = groups[sig]
        entry['count'] += 1
        ts_match = re.match(r'\[([0-9T:\- ]+)\]', line)
        ts = ts_match.group(1) if ts_match else None
        if ts:
            entry['last'] = ts
            if entry['first'] is None:
                entry['first'] = ts
        if not entry['sample']:
            entry['sample'] = line.strip()[:300]

top = sorted(groups.items(), key=lambda kv: kv[1]['count'], reverse=True)[:20]

out = {
    'total_distinct_signatures': len(groups),
    'top_20': [
        {
            'signature': sig,
            'count': entry['count'],
            'first': entry['first'],
            'last': entry['last'],
            'sample': entry['sample'],
        }
        for sig, entry in top
    ],
}
print(json.dumps(out, indent=2))
PY
