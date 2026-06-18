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

# Secrets live OUTSIDE app/code too — most importantly the crypt key in app/etc/env.php. Default
# to the whole `app/` tree (custom code + app/etc + design/i18n) so env.php is covered, but NOT
# vendor/var/pub/generated (third-party noise). An explicit path argument still wins.
if [ -n "${1:-}" ]; then
    SCAN_PATH="$1"
elif [ -d app/etc ]; then
    SCAN_PATH="app"
elif [ -d src/app/etc ]; then
    SCAN_PATH="src/app"
elif [ -d app/code ]; then
    SCAN_PATH="app/code"
else
    SCAN_PATH="src/app/code"
fi
SCRIPT_DIR="$(dirname "$0")"

if command -v gitleaks >/dev/null 2>&1; then
    # gitleaks writes its JSON to the --report-path file, NOT to stdout. The old pipe read
    # stdout (which carries only a human summary), so json.load() got nothing and every run
    # reported zero secrets — installing the better tool silently disabled detection (SEC-3).
    # --no-git scans the files as-is (the module dir is usually not a git root). Exit codes:
    # 0 = no leaks, 1 = leaks found, >1 = real error (fall through to the next tool).
    GL_REPORT="$(mktemp)"
    GL_ERR="$(mktemp)"
    gitleaks detect --no-banner --no-git --report-format=json \
        --report-path="$GL_REPORT" --source="$SCAN_PATH" >/dev/null 2>"$GL_ERR"
    gl_rc=$?
    if [ "$gl_rc" -le 1 ]; then
        python3 -c '
import json, sys
try:
    data = json.load(open(sys.argv[1]))
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
' "$GL_REPORT"
        rm -f "$GL_REPORT" "$GL_ERR"
        exit 0
    fi
    # gitleaks errored — do NOT exit 0 with empty results. Surface it and fall through to the
    # next available tool / regex fallback so secret detection still runs.
    echo "secret-scan: gitleaks failed (exit ${gl_rc}): $(head -c 300 "$GL_ERR" | tr -d '\n') — falling back" >&2
    rm -f "$GL_REPORT" "$GL_ERR"
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
    # Map severity off the trufflehog Verified flag rather than hardcoding Critical: a
    # verified live secret is Critical; an unverified regex hit is High (verify before acting).
    verified = bool(f.get("Verified"))
    out.append({
        "id": f"security-audit-secret-{i+1:03d}",
        "severity": "critical" if verified else "high",
        "category": "secret",
        "title": f.get("DetectorName", "Secret detected") + ("" if verified else " (unverified)"),
        "evidence": [{"file": f.get("SourceMetadata", {}).get("Data", {}).get("Filesystem", {}).get("file", "?"), "line": f.get("SourceMetadata", {}).get("Data", {}).get("Filesystem", {}).get("line", 1)}],
        "recommendation": "Rotate the secret immediately." if verified else "Verify, then rotate if live.",
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

# Full pack mirroring references/secret-patterns.md (the old list shipped 7 of ~18 and
# none of the 3 Magento-specific patterns). Severity per the doc's mapping table.
PATTERNS = [
    # AWS
    ('aws-access-key-id', 'critical', re.compile(rb'AKIA[0-9A-Z]{16}')),
    ('aws-secret-access-key', 'critical',
     re.compile(rb'aws_secret_access_key["\']?\s*[=:]\s*["\'][A-Za-z0-9/+]{40}["\']')),
    # Stripe
    ('stripe-live-secret', 'critical', re.compile(rb'sk_live_[0-9a-zA-Z]{24,99}')),
    ('stripe-test-secret', 'low', re.compile(rb'sk_test_[0-9a-zA-Z]{24,99}')),
    ('stripe-webhook-secret', 'high', re.compile(rb'whsec_[a-zA-Z0-9]{32,99}')),
    # GitHub
    ('github-pat', 'high', re.compile(rb'ghp_[A-Za-z0-9]{36}')),
    ('github-fine-grained-pat', 'high', re.compile(rb'github_pat_[A-Za-z0-9_]{82}')),
    ('github-server-token', 'high', re.compile(rb'ghs_[A-Za-z0-9]{36}')),
    # Google
    ('google-api-key', 'high', re.compile(rb'AIza[0-9A-Za-z\-_]{35}')),
    # Generic
    ('jwt', 'medium', re.compile(rb'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}')),
    ('bearer-token', 'high', re.compile(rb'Bearer\s+[A-Za-z0-9._-]{32,}')),
    ('rsa-private-key', 'critical', re.compile(rb'-----BEGIN (?:RSA )?PRIVATE KEY-----')),
    ('ssh-private-key', 'critical', re.compile(rb'-----BEGIN OPENSSH PRIVATE KEY-----')),
    ('password-define', 'high',
     re.compile(rb"define\(['\"](?:DB_PASSWORD|PASSWORD|SECRET)['\"]\s*,\s*['\"][^'\"]{6,}['\"]\)")),
    # Magento-specific (were entirely missing)
    ('magento-crypt-key', 'critical',
     re.compile(rb"['\"]crypt['\"].{0,40}['\"]key['\"]\s*=>\s*['\"][a-f0-9]{32,}['\"]")),
    ('magento-marketplace-token', 'high',
     re.compile(rb'repo\.magento\.com.{0,200}[a-f0-9]{32}|[a-f0-9]{32}.{0,200}repo\.magento\.com')),
    ('magento-admin-reset-token', 'high', re.compile(rb'key/[a-f0-9]{64}/')),
]

# Canonical-doc examples and template placeholders must NOT be flagged as live secrets.
# Without this, AWS's own documented example key (AKIAIOSFODNN7EXAMPLE) reads as Critical.
PLACEHOLDER_MARKERS = [
    b'example', b'xxxx', b'your_', b'your-', b'replace-me', b'replaceme',
    b'placeholder', b'changeme', b'change-me', b'dummy', b'test-secret',
    b'redacted', b'<your', b'sample',
]


def _line_of(content, start, end):
    ls = content.rfind(b'\n', 0, start) + 1
    le = content.find(b'\n', end)
    return content[ls:(le if le != -1 else len(content))]


def _is_placeholder(match_bytes, line_bytes):
    blob = (match_bytes + b' ' + line_bytes).lower()
    return any(marker in blob for marker in PLACEHOLDER_MARKERS)


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
                line_bytes = _line_of(content, m.start(), m.end())
                if _is_placeholder(m.group(0), line_bytes):
                    continue
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
