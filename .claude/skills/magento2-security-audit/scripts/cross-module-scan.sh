#!/usr/bin/env bash
# cross-module-scan.sh — detect cross-module collisions and graph issues.
#
# Output: JSON array of finding objects.

set -uo pipefail

MODULE_DIR="${1:-src/app/code}"
[ -d "$MODULE_DIR" ] || { echo "[]"; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 2
fi

python3 - "$MODULE_DIR" <<'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

base = sys.argv[1].rstrip('/')

preferences = {}  # for -> [(file, vendor_module)]
cron_jobs = {}    # job name -> [files]
sequences = {}    # module -> [dependencies]
out = []
fid = 1


def walk_xml(path, tag, attr, register):
    try:
        tree = ET.parse(path)
    except Exception:
        return
    for el in tree.iter(tag):
        val = el.get(attr)
        if val:
            register(val, path)


for vendor in os.listdir(base):
    vendor_path = os.path.join(base, vendor)
    if not os.path.isdir(vendor_path):
        continue
    for module in os.listdir(vendor_path):
        module_path = os.path.join(vendor_path, module)
        if not os.path.isdir(module_path):
            continue
        vm = f'{vendor}_{module}'

        # Preferences
        for di_path in [
            os.path.join(module_path, 'etc', 'di.xml'),
            os.path.join(module_path, 'etc', 'frontend', 'di.xml'),
            os.path.join(module_path, 'etc', 'adminhtml', 'di.xml'),
            os.path.join(module_path, 'etc', 'webapi_rest', 'di.xml'),
            os.path.join(module_path, 'etc', 'webapi_soap', 'di.xml'),
            os.path.join(module_path, 'etc', 'graphql', 'di.xml'),
        ]:
            if os.path.exists(di_path):
                walk_xml(di_path, '{*}preference', 'for', lambda v, p: preferences.setdefault(v, []).append((p, vm)))
                walk_xml(di_path, 'preference', 'for', lambda v, p: preferences.setdefault(v, []).append((p, vm)))

        # Cron jobs
        cron_path = os.path.join(module_path, 'etc', 'crontab.xml')
        if os.path.exists(cron_path):
            walk_xml(cron_path, '{*}job', 'name', lambda v, p: cron_jobs.setdefault(v, []).append((p, vm)))
            walk_xml(cron_path, 'job', 'name', lambda v, p: cron_jobs.setdefault(v, []).append((p, vm)))

        # Sequences
        mod_path = os.path.join(module_path, 'etc', 'module.xml')
        if os.path.exists(mod_path):
            try:
                tree = ET.parse(mod_path)
                for el in tree.iter():
                    tag = el.tag.split('}')[-1]
                    if tag == 'sequence':
                        for child in list(el):
                            ctag = child.tag.split('}')[-1]
                            if ctag == 'module':
                                sequences.setdefault(vm, []).append(child.get('name'))
            except Exception:
                pass


# Emit findings
for target, refs in preferences.items():
    distinct = sorted({vm for _, vm in refs})
    if len(distinct) > 1:
        out.append({
            'id': f'security-audit-collision-{fid:03d}',
            'severity': 'high',
            'category': 'preference-collision',
            'title': f"Multiple modules <preference for=\"{target}\">",
            'evidence': [{'file': p, 'line': 1} for p, _ in refs],
            'recommendation': f"Resolve the collision: one of {', '.join(distinct)} must remove its preference, or coordinate via di:override:order.",
            'verification': 'Re-run audit; collision should not reappear.',
            'tags': list(distinct)
        })
        fid += 1

for job, refs in cron_jobs.items():
    if len({vm for _, vm in refs}) > 1:
        out.append({
            'id': f'security-audit-collision-{fid:03d}',
            'severity': 'medium',
            'category': 'preference-collision',
            'subcategory': 'cron-name-collision',
            'title': f"Multiple modules register cron job \"{job}\"",
            'evidence': [{'file': p, 'line': 1} for p, _ in refs],
            'recommendation': f"Rename one of the cron jobs to avoid silent override.",
            'verification': 'Re-run audit; collision should not reappear.'
        })
        fid += 1

# Sequence cycle detection (simple)
def has_cycle(graph):
    visited, stack = set(), set()
    def visit(n):
        if n in stack: return True
        if n in visited: return False
        visited.add(n); stack.add(n)
        for nb in graph.get(n, []):
            if visit(nb): return True
        stack.discard(n)
        return False
    return any(visit(n) for n in graph)

if has_cycle(sequences):
    out.append({
        'id': f'security-audit-collision-{fid:03d}',
        'severity': 'high',
        'category': 'preference-collision',
        'subcategory': 'sequence-cycle',
        'title': "Module <sequence> graph contains a cycle",
        'evidence': [{'file': f'{base}/*/*/etc/module.xml', 'line': 1}],
        'recommendation': "Inspect each module's <sequence> block; remove the cyclic dependency.",
        'verification': 'Re-run audit.'
    })
    fid += 1

print(json.dumps(out, indent=2))
PY
