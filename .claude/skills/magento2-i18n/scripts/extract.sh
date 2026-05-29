#!/usr/bin/env bash
# extract.sh — extract translatable phrases from a module.
#
# Strategy:
#   1. Try Magento CLI: bin/magento i18n:collect-phrases
#   2. Fall back to regex scan via python.
#
# Usage:
#   extract.sh <module-path> [output-csv]
#
# Output: CSV with one row per unique source phrase: `"Phrase",""`.

set -uo pipefail

MODULE_PATH="${1:?usage: extract.sh <module-path> [output-csv]}"
OUTPUT="${2:-/dev/stdout}"

[ -d "$MODULE_PATH" ] || { echo "extract: not a directory: $MODULE_PATH" >&2; exit 2; }

# Try Magento CLI first
if [ -f .claude/.cache/magento2-context.json ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('.claude/.cache/magento2-context.json')).get('magento_cli') or '')")"
    if [ -n "$MAGENTO_CLI" ]; then
        if eval "$MAGENTO_CLI i18n:collect-phrases" "$MODULE_PATH" -o "$OUTPUT" 2>/dev/null; then
            echo "extract: used magento i18n:collect-phrases" >&2
            exit 0
        fi
    fi
fi

# Regex fallback
if ! command -v python3 >/dev/null 2>&1; then
    echo "extract: python3 required for fallback" >&2
    exit 3
fi

python3 - "$MODULE_PATH" "$OUTPUT" <<'PY'
import csv
import os
import re
import sys

base = sys.argv[1]
out_path = sys.argv[2]

PHP_PATTERNS = [
    re.compile(r"""__\(\s*['"]((?:\\.|[^'"\\])+)['"]\s*[,)]"""),
]

XML_PATTERNS = [
    re.compile(r'<(?:label|title)[^>]*translate=["\']true["\'][^>]*>([^<]+)</'),
    re.compile(r'<(?:argument|item)[^>]+translate=["\']true["\'][^>]*>([^<]+)</'),
]

JS_PATTERNS = [
    re.compile(r"""(?:\$\.mage\.__|\$t)\(\s*['"]((?:\\.|[^'"\\])+)['"]\s*\)"""),
]

phrases = set()

for root, _, files in os.walk(base):
    if '/Test/' in root:
        continue
    for name in files:
        path = os.path.join(root, name)
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                content = fh.read()
        except Exception:
            continue
        if name.endswith(('.php', '.phtml')):
            for p in PHP_PATTERNS:
                phrases.update(m.group(1) for m in p.finditer(content))
        if name.endswith('.xml') or name.endswith('.phtml'):
            for p in XML_PATTERNS:
                phrases.update(m.group(1) for m in p.finditer(content))
        if name.endswith('.js') or name.endswith('.html'):
            for p in JS_PATTERNS:
                phrases.update(m.group(1) for m in p.finditer(content))

# Filter: at least one letter
phrases = sorted(p for p in phrases if re.search(r'[A-Za-z]', p))

if out_path == '/dev/stdout':
    out = sys.stdout
else:
    out = open(out_path, 'w', encoding='utf-8', newline='')
writer = csv.writer(out, quoting=csv.QUOTE_ALL)
for p in phrases:
    writer.writerow([p, ''])
if out_path != '/dev/stdout':
    out.close()

print(f"extract: emitted {len(phrases)} unique phrases", file=sys.stderr)
PY
