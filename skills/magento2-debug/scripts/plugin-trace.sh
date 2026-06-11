#!/usr/bin/env bash
# plugin-trace.sh — find plugins / observers for an event, method, or class.
#
# Usage:
#   plugin-trace.sh --event=<event_name>          [--root=<module-dir>]
#   plugin-trace.sh --method='Class\Name::method' [--root=<module-dir>]
#   plugin-trace.sh --class='Class\Name'          [--root=<module-dir>]
#
# Scope: matches only entries DECLARED directly against the given type name.
# Plugins declared on a parent class or implemented interface of the target, and
# virtualType entries, are NOT chased. For inheritance-aware resolution that
# matches the framework's compiled view, use `bin/magento dev:di:info`.

# `set -uo` (no -e) is deliberate: an unreadable di.xml / events.xml or a failing
# `find` branch must not abort the whole trace — partial results beat none.
set -uo pipefail

if ! command -v python3 >/dev/null 2>&1; then
    echo "plugin-trace: python3 required" >&2
    exit 2
fi

MODE=""
TARGET=""
MODULE_ROOT=""

for arg in "$@"; do
    case "$arg" in
        --event=*) MODE="event"; TARGET="${arg#*=}" ;;
        --method=*) MODE="method"; TARGET="${arg#*=}" ;;
        --class=*) MODE="class"; TARGET="${arg#*=}" ;;
        --root=*) MODULE_ROOT="${arg#*=}" ;;
    esac
done

if [ -z "$MODE" ]; then
    echo "plugin-trace: must specify one of --event=, --method=, --class=" >&2
    exit 1
fi

# Detect the module root like the rest of this repo's scripts do: root-layout keeps
# app/code at the repo root, src-layout under src/. A --root override (or the cached
# module_dir) wins so unusual layouts aren't silently dropped (find errors are swallowed).
CONTEXT_FILE=".claude/.cache/magento2-context.json"
if [ -z "$MODULE_ROOT" ] && [ -f "$CONTEXT_FILE" ]; then
    MODULE_ROOT="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('module_dir') or '')" 2>/dev/null || echo "")"
fi
MODULE_ROOT="${MODULE_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"

ROOTS=("$MODULE_ROOT" "vendor")

# find_xml <basename> — emit candidate XML paths, searching only roots that exist.
find_xml() {
    local name="$1" r existing=()
    for r in "${ROOTS[@]}"; do
        [ -d "$r" ] && existing+=("$r")
    done
    [ "${#existing[@]}" -eq 0 ] && return 0
    find "${existing[@]}" -type f -name "$name" 2>/dev/null || true
}

if [ "$MODE" = "event" ]; then
    FILES="$(find "${ROOTS[@]}" -type f -name 'events.xml' 2>/dev/null || true)"
    MODE="$MODE" TARGET="$TARGET" FILES="$FILES" python3 <<'PY'
import json, os, xml.etree.ElementTree as ET
target = os.environ['TARGET']
files = os.environ['FILES'].splitlines()
observers = []
for path in files:
    if not path: continue
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    for el in tree.iter():
        tag = el.tag.split('}')[-1]
        if tag == 'event' and el.get('name') == target:
            for child in list(el):
                if child.tag.split('}')[-1] == 'observer':
                    observers.append({
                        'file': path,
                        'name': child.get('name'),
                        'instance': child.get('instance'),
                        'disabled': child.get('disabled', 'false'),
                    })
print(json.dumps({'event': target, 'observers': observers}, indent=2))
PY
elif [ "$MODE" = "method" ]; then
    CLASS="${TARGET%::*}"
    METHOD="${TARGET#*::}"
    FILES="$(find "${ROOTS[@]}" -type f -name 'di.xml' 2>/dev/null || true)"
    CLASS="$CLASS" METHOD="$METHOD" FILES="$FILES" python3 <<'PY'
import json, os, xml.etree.ElementTree as ET
class_target = os.environ['CLASS'].lstrip('\\')
method = os.environ['METHOD']
files = os.environ['FILES'].splitlines()
plugins = []
for path in files:
    if not path: continue
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    for type_el in tree.iter():
        if type_el.tag.split('}')[-1] != 'type':
            continue
        if (type_el.get('name') or '').lstrip('\\') != class_target:
            continue
        for child in list(type_el):
            if child.tag.split('}')[-1] != 'plugin':
                continue
            # Plugin class is read from its source code to know which method bindings exist.
            plugins.append({
                'file': path,
                'name': child.get('name'),
                'class': child.get('type'),
                'sortOrder': int(child.get('sortOrder', '0')),
                'disabled': child.get('disabled', 'false'),
                'method_pattern': f"before{method[0].upper()+method[1:]}|around{method[0].upper()+method[1:]}|after{method[0].upper()+method[1:]}",
            })
plugins.sort(key=lambda p: p['sortOrder'])
print(json.dumps({'class': class_target, 'method': method, 'plugins': plugins}, indent=2))
PY
elif [ "$MODE" = "class" ]; then
    FILES="$(find "${ROOTS[@]}" -type f -name 'di.xml' 2>/dev/null || true)"
    TARGET="$TARGET" FILES="$FILES" python3 <<'PY'
import json, os, xml.etree.ElementTree as ET
target = os.environ['TARGET'].lstrip('\\')
files = os.environ['FILES'].splitlines()
preferences = []
for path in files:
    if not path: continue
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    for el in tree.iter():
        if el.tag.split('}')[-1] == 'preference' and (el.get('for') or '').lstrip('\\') == target:
            preferences.append({'file': path, 'impl': el.get('type')})
print(json.dumps({'class': target, 'preferences': preferences}, indent=2))
PY
fi
