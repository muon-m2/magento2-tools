#!/usr/bin/env bash
# di-walk.sh — find DI preferences, plugins, argument bindings for a type.
#
# Usage:
#   di-walk.sh <fqcn>

set -uo pipefail

FQCN="${1:?usage: di-walk.sh <fqcn>}"
ROOTS=("src/app/code" "vendor")

if ! command -v python3 >/dev/null 2>&1; then
    echo "di-walk: python3 required" >&2
    exit 2
fi

# Collect candidate di.xml paths
FILES="$(find "${ROOTS[@]}" -type f -name 'di.xml' 2>/dev/null || true)"

FQCN="$FQCN" FILES="$FILES" python3 <<'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

fqcn = os.environ['FQCN']
files = os.environ.get('FILES', '').strip().splitlines()

preferences = []
plugins = []
args = []


def normalize(s: str) -> str:
    return s.lstrip('\\').strip() if s else s


target = normalize(fqcn)

for path in files:
    if not path:
        continue
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    for el in tree.iter():
        tag = el.tag.split('}')[-1]
        if tag == 'preference' and normalize(el.get('for') or '') == target:
            preferences.append({'file': path, 'impl': el.get('type')})
        if tag == 'type' and normalize(el.get('name') or '') == target:
            for child in list(el):
                ctag = child.tag.split('}')[-1]
                if ctag == 'plugin':
                    plugins.append({
                        'file': path,
                        'name': child.get('name'),
                        'class': child.get('type'),
                        'sortOrder': int(child.get('sortOrder', '0')),
                        'disabled': child.get('disabled', 'false'),
                    })
                if ctag == 'arguments':
                    for arg in child.findall('{*}argument'):
                        args.append({
                            'file': path,
                            'arg': arg.get('name'),
                            'type': arg.get('{http://www.w3.org/2001/XMLSchema-instance}type'),
                            'value': (arg.text or '').strip(),
                        })

plugins.sort(key=lambda p: (p['sortOrder'], p['name'] or ''))

print(json.dumps({
    'target': fqcn,
    'preferences': preferences,
    'plugins': plugins,
    'argument_overrides': args,
}, indent=2))
PY
