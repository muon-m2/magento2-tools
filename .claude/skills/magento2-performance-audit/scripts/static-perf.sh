#!/usr/bin/env bash
# static-perf.sh — static pattern scan over a module's PHP source.
#
# Emits a JSON array of finding objects per the shared findings schema.

set -uo pipefail

MODULE_PATH="${1:?usage: static-perf.sh <module-path>}"
[ -d "$MODULE_PATH" ] || { echo "[]"; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 2
fi

python3 - "$MODULE_PATH" <<'PY'
import json
import os
import re
import sys

base = sys.argv[1].rstrip('/')

PATTERNS = [
    # (id, category, severity, regex, title, recommendation)
    ('n_plus_one_repo', 'n_plus_one', 'high',
     re.compile(r'foreach\s*\([^)]+\)\s*\{[^}]{0,500}Repository->(get|getById)\s*\('),
     'Repository call inside foreach (1+N)',
     'Pre-fetch via getList(addFilter(... in ids)) before the loop.'),
    ('n_plus_one_load', 'n_plus_one', 'high',
     re.compile(r'foreach\s*\([^)]+\)\s*\{[^}]{0,500}Factory->create\s*\([^)]*\)\s*->load\s*\('),
     'Factory->create->load inside foreach (1+N)',
     'Pre-fetch via a collection or batch repository call.'),
    ('full_collection', 'cache', 'medium',
     re.compile(r'getCollection\s*\(\s*\)\s*->getItems\s*\(\s*\)'),
     'getCollection()->getItems() without filter',
     'Apply addFieldToFilter() and setPageSize() before iterating.'),
    ('constructor_db', 'constructor-work', 'medium',
     re.compile(r'function\s+__construct\([^{]*\)\s*\{[^}]{0,500}->getConnection\s*\(\s*\)'),
     'DB call in __construct',
     'Defer DB access to method body; constructors should be cheap.'),
    ('constructor_http', 'constructor-work', 'medium',
     re.compile(r'function\s+__construct\([^{]*\)\s*\{[^}]{0,500}->(post|get|request|curl_exec)\s*\('),
     'HTTP call in __construct',
     'Defer HTTP calls to method body.'),
    ('around_plugin', 'plugin-hotpath', 'medium',
     re.compile(r'function\s+around[A-Z]\w*\s*\(([^)]*)\)'),
     'around plugin defined',
     'Around plugins are expensive; prefer before/after when possible.'),
    ('block_no_identity', 'cache-identity', 'medium',
     re.compile(r'class\s+\w+\s+extends\s+(\\Magento\\Framework\\View\\Element\\Template|AbstractBlock)[^{]*\{'),
     'Block without getIdentities override (check manually)',
     'Add getIdentities() returning the cache tags this block depends on.'),
    ('storefront_curl', 'storefront-http', 'high',
     re.compile(r'class\s+\w+\s+extends\s+(\\Magento\\Framework\\View\\Element\\Template|AbstractBlock)[^{]*\{[^}]{0,2000}->(post|get|request|curl_exec)\s*\('),
     'HTTP call inside a Block class',
     'Move HTTP to a service; cache the result. Storefront blocks must not block on external HTTP.'),
]

out = []
fid = 1

for root, _, files in os.walk(base):
    if '/Test/' in root or '/vendor/' in root:
        continue
    for name in files:
        if not name.endswith('.php'):
            continue
        path = os.path.join(root, name)
        try:
            with open(path, encoding='utf-8') as fh:
                content = fh.read()
        except Exception:
            continue
        rel = os.path.relpath(path, base)
        for pid, category, severity, regex, title, recommendation in PATTERNS:
            for m in regex.finditer(content):
                line = content[:m.start()].count('\n') + 1
                # Honor // @perf-audit-ignore reason="..."
                line_content = content.splitlines()[line-1] if line-1 < len(content.splitlines()) else ''
                surrounding = content[max(0, m.start()-200):m.start()+200]
                if '@perf-audit-ignore' in surrounding:
                    continue
                out.append({
                    'id': f'perf-audit-static-{fid:03d}',
                    'severity': severity,
                    'category': category,
                    'subcategory': pid,
                    'title': title,
                    'evidence': [{'file': rel, 'line': line, 'snippet': line_content.strip()[:200]}],
                    'recommendation': recommendation,
                    'verification': 'Re-run static-perf.sh; pattern should not re-match.'
                })
                fid += 1

print(json.dumps(out, indent=2))
PY
