#!/usr/bin/env bash
# secret-scan.sh — find committed secrets.
#
# Strategy:
#   1. Try gitleaks (preferred — purpose-built).
#   2. Try trufflehog (alternative).
#   3. Fall back to regex pack from references/secret-patterns.md.
#
# Output: JSON array of finding objects per the shared findings schema.

set -uo pipefail

SCAN_PATH="${1:-src/app/code}"
SCRIPT_DIR="$(dirname "$0")"

if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --no-banner --report-format=json --source="$SCAN_PATH" 2>/dev/null \
        | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
out = []
for i, f in enumerate(data or []):
    out.append({
        "id": f"security-audit-secret-{i+1:03d}",
        "severity": "critical",
        "category": "secret",
        "title": f.get("Description", "Secret detected"),
        "evidence": [{"file": f.get("File", "?"), "line": f.get("StartLine", 1)}],
        "recommendation": "Rotate the secret immediately. Move to env vars or encrypted config. Remove from git history.",
        "verification": "Re-run scan after rotation."
    })
print(json.dumps(out, indent=2))
'
    exit 0
fi

if command -v trufflehog >/dev/null 2>&1; then
    trufflehog filesystem --json "$SCAN_PATH" 2>/dev/null \
        | python3 -c '
import json, sys
out = []
for i, line in enumerate(sys.stdin):
    try:
        f = json.loads(line)
    except Exception:
        continue
    out.append({
        "id": f"security-audit-secret-{i+1:03d}",
        "severity": "critical",
        "category": "secret",
        "title": f.get("DetectorName", "Secret detected"),
        "evidence": [{"file": f.get("SourceMetadata", {}).get("Data", {}).get("Filesystem", {}).get("file", "?"), "line": f.get("SourceMetadata", {}).get("Data", {}).get("Filesystem", {}).get("line", 1)}],
        "recommendation": "Rotate the secret immediately.",
        "verification": "Re-run scan."
    })
print(json.dumps(out, indent=2))
'
    exit 0
fi

# Regex fallback
python3 - "$SCAN_PATH" <<'PY'
import json
import os
import re
import sys

path = sys.argv[1]

PATTERNS = [
    ('aws-access-key', 'critical', re.compile(rb'AKIA[0-9A-Z]{16}')),
    ('stripe-live-secret', 'critical', re.compile(rb'sk_live_[0-9a-zA-Z]{24,99}')),
    ('github-pat', 'high', re.compile(rb'ghp_[A-Za-z0-9]{36}')),
    ('rsa-private-key', 'critical', re.compile(rb'-----BEGIN (?:RSA )?PRIVATE KEY-----')),
    ('bearer-token', 'high', re.compile(rb'Bearer\s+[A-Za-z0-9._-]{32,}')),
    ('google-api-key', 'high', re.compile(rb'AIza[0-9A-Za-z\-_]{35}')),
    ('password-define', 'high', re.compile(rb"define\(['\"](?:DB_PASSWORD|PASSWORD|SECRET)['\"]\s*,\s*['\"][^'\"]{6,}['\"]\)")),
]

EXCLUDE_DIRS = {'vendor', 'node_modules', 'var', 'generated', 'pub/static'}

out = []
fid = 1
for root, dirs, files in os.walk(path):
    dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
    for name in files:
        full = os.path.join(root, name)
        try:
            with open(full, 'rb') as fh:
                content = fh.read()
        except Exception:
            continue
        for pname, sev, pat in PATTERNS:
            for m in pat.finditer(content):
                line_no = content[:m.start()].count(b'\n') + 1
                out.append({
                    'id': f'security-audit-secret-{fid:03d}',
                    'severity': sev,
                    'category': 'secret',
                    'subcategory': pname,
                    'title': f'Possible {pname} in source',
                    'evidence': [{'file': full, 'line': line_no}],
                    'recommendation': 'Rotate secret immediately. Move to env vars or encrypted config. Remove from git history.',
                    'verification': 'Re-run scan after rotation.'
                })
                fid += 1

print(json.dumps(out, indent=2))
PY
