#!/usr/bin/env bash
# coverage-gap.sh — find source classes without a corresponding test.
#
# Usage:
#   coverage-gap.sh <module-path>
#
# Emits JSON to stdout:
#   {
#     "module": "src/app/code/Acme/Catalog",
#     "untested": [
#       {"source": "Service/PriceCalculator.php", "expected_test": "Test/Unit/Service/PriceCalculatorTest.php", "type": "service"}
#     ]
#   }

set -uo pipefail

MODULE_PATH="${1:?usage: coverage-gap.sh <module-path>}"
[ -d "$MODULE_PATH" ] || { echo "coverage-gap: not a directory: $MODULE_PATH" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "coverage-gap: python3 required" >&2
    exit 3
fi

python3 - "$MODULE_PATH" <<'PY'
import json
import os
import sys

module_path = sys.argv[1].rstrip('/')

TYPE_DIRS = [
    ('Api', 'api'),
    ('Service', 'service'),
    ('Model/Resolver', 'resolver'),
    ('Model', 'model'),
    ('Plugin', 'plugin'),
    ('Observer', 'observer'),
    ('Cron', 'cron'),
    ('Queue', 'consumer'),
    ('Controller', 'controller'),
    ('ViewModel', 'viewmodel'),
    ('Block', 'block'),
]

untested = []
# os.walk recurses, so a nested type dir (e.g. Model/Resolver) is also walked when its parent
# (Model) is processed. TYPE_DIRS lists the more-specific dir first; `seen` keeps each source
# file classified once under that first match instead of being emitted twice with two types.
seen = set()

for subdir, kind in TYPE_DIRS:
    src_root = os.path.join(module_path, subdir)
    if not os.path.isdir(src_root):
        continue
    for root, dirs, files in os.walk(src_root):
        if '/Test/' in root or root.endswith('/Test'):
            continue
        for name in files:
            if not name.endswith('.php'):
                continue
            full = os.path.join(root, name)
            if full in seen:
                continue
            seen.add(full)
            rel = os.path.relpath(full, module_path)
            base = name[:-4]
            test_rel = os.path.join('Test', 'Unit', os.path.relpath(root, module_path), base + 'Test.php')
            test_full = os.path.join(module_path, test_rel)
            if not os.path.exists(test_full):
                untested.append({
                    'source': rel,
                    'expected_test': test_rel,
                    'type': kind,
                })

print(json.dumps({'module': module_path, 'untested': untested}, indent=2))
PY
