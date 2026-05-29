#!/usr/bin/env bash
# validate-csv.sh — check Magento translation CSV well-formedness + placeholder consistency.
#
# Usage:
#   validate-csv.sh <csv-path>
#
# Output: JSON document with validation results.

set -uo pipefail

CSV="${1:?usage: validate-csv.sh <csv-path>}"
[ -f "$CSV" ] || { echo "validate-csv: file not found: $CSV" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "validate-csv: python3 required" >&2
    exit 3
fi

python3 - "$CSV" <<'PY'
import csv
import json
import os
import re
import sys

path = sys.argv[1]

issues = []
row_count = 0
empty_translation_count = 0
mismatch_count = 0

# Encoding check
with open(path, 'rb') as fh:
    raw = fh.read()
if raw.startswith(b'\xef\xbb\xbf'):
    issues.append({'severity': 'medium', 'type': 'encoding', 'detail': 'BOM detected (Magento expects no BOM)'})
try:
    raw.decode('utf-8')
except UnicodeDecodeError as exc:
    issues.append({'severity': 'medium', 'type': 'encoding', 'detail': f'Not valid UTF-8: {exc}'})

# Parse rows
def placeholders(s: str):
    return set(re.findall(r'%(\d+|s)', s))

with open(path, encoding='utf-8', errors='replace', newline='') as fh:
    reader = csv.reader(fh)
    for line_no, row in enumerate(reader, start=1):
        if not row:
            continue
        row_count += 1
        if len(row) != 2:
            issues.append({'severity': 'medium', 'type': 'row-shape',
                           'line': line_no, 'detail': f'expected 2 fields, got {len(row)}'})
            continue
        source, target = row
        if not target:
            empty_translation_count += 1
            continue
        if placeholders(source) != placeholders(target):
            mismatch_count += 1
            issues.append({
                'severity': 'medium',
                'type': 'placeholder-mismatch',
                'line': line_no,
                'source': source,
                'target': target,
                'detail': f'source={sorted(placeholders(source))}, target={sorted(placeholders(target))}'
            })

print(json.dumps({
    'csv': path,
    'row_count': row_count,
    'empty_translations': empty_translation_count,
    'placeholder_mismatches': mismatch_count,
    'issues': issues,
    'valid': not issues
}, indent=2))
PY
