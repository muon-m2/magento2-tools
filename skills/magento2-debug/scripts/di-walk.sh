#!/usr/bin/env bash
# di-walk.sh — find DI preferences, plugins, argument bindings for a type.
#
# Usage:
#   di-walk.sh <fqcn> [--root=<module-dir>]
#
# Scope: lists DECLARED preferences/plugins/argument-bindings whose <preference for>
# / <type name> matches <fqcn> exactly. It does NOT resolve plugins inherited from
# parent classes or implemented interfaces, and does NOT expand virtualType entries.
# For authoritative inheritance-aware resolution use `bin/magento dev:di:info`.

# `set -uo` (no -e) is deliberate: a single unreadable di.xml or a failing `find`
# branch must not abort the whole walk — partial results are more useful than none.
set -uo pipefail

# Detect the module root like the rest of this repo's scripts do: root-layout
# projects keep app/code at the repo root, src-layout projects under src/. A
# --root override (or the cached module_dir) takes precedence so callers on an
# unusual layout aren't silently dropped.
MODULE_ROOT=""
for arg in "$@"; do
    case "$arg" in
        --root=*) MODULE_ROOT="${arg#*=}" ;;
    esac
done

FQCN="${1:?usage: di-walk.sh <fqcn> [--root=<module-dir>]}"

CONTEXT_FILE=".claude/.cache/magento2-context.json"
if [ -z "$MODULE_ROOT" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MODULE_ROOT="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('module_dir') or '')" 2>/dev/null || echo "")"
fi
MODULE_ROOT="${MODULE_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"

ROOTS=("$MODULE_ROOT" "vendor")

if ! command -v python3 >/dev/null 2>&1; then
    echo "di-walk: python3 required" >&2
    exit 2
fi

# Collect candidate di.xml paths. Only search roots that exist so a missing
# vendor/ (or src-vs-root mismatch) degrades gracefully instead of erroring out.
EXISTING_ROOTS=()
for r in "${ROOTS[@]}"; do
    [ -d "$r" ] && EXISTING_ROOTS+=("$r")
done
if [ "${#EXISTING_ROOTS[@]}" -eq 0 ]; then
    echo "di-walk: no DI roots found (looked in: ${ROOTS[*]})" >&2
    exit 2
fi
FILES="$(find "${EXISTING_ROOTS[@]}" -type f -name 'di.xml' 2>/dev/null || true)"

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
    'scope': ('declared entries matching this exact type only; '
              'plugins on parent classes/interfaces and virtualType expansion '
              'are NOT resolved — use bin/magento dev:di:info for those'),
    'preferences': preferences,
    'plugins': plugins,
    'argument_overrides': args,
}, indent=2))
PY
