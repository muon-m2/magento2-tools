#!/usr/bin/env bash
# static-scan.sh — scan a module subtree for Breeze incompatibility patterns and emit a JSON
# array of findings (shared findings-schema.md Finding shape) to stdout.
#
# Read-only. No running Magento instance required.
#
# Usage: static-scan.sh <target-path>
#   <target-path>  module dir to scan (e.g. app/code/Acme/Foo). Missing dir → "[]".
#
# Detects (see ../references/breeze-compat-checklist.md):
#   requirejs    requirejs-config.js present; inline require([...]) in .phtml
#   mixin        requirejs-config.js declaring `mixins`
#   knockout     uiComponent / Magento_Ui/js dependency; data-bind templates
#   jquery-widget  $.widget / $.mage usage
#   magento-init data-mage-init / text/x-magento-init (Info — Breeze supports these)
#   assets       ships frontend assets but no breeze_* layout / web/css/breeze adapter
#
# Storefront-only: view/adminhtml is skipped; Breeze adapter modules (*Breeze, *-breeze, web/*/breeze/)
# are skipped; an adapter (sibling or self) downgrades requirejs-config to info; checkout KO is info.
set -uo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
    printf '[]\n'
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf '[]\n'
    exit 0
fi

python3 - "$TARGET" <<'PY'
import os
import re
import sys
import json
from datetime import datetime, timezone

target = sys.argv[1].rstrip('/')
date = datetime.now(timezone.utc).strftime('%Y-%m-%d')

findings = []
seq = 0
CAP = 300


def add(severity, category, title, file, line, recommendation, verification, subcategory=None):
    global seq
    if len(findings) >= CAP:
        return
    seq += 1
    f = {
        'id': f'breeze-compat-{date}-{seq:03d}',
        'severity': severity,
        'category': category,
        'title': title,
        'evidence': [{'file': file, 'line': line}],
        'recommendation': recommendation,
        'verification': verification,
        'confidence': 'candidate',
    }
    if subcategory:
        f['subcategory'] = subcategory
    findings.append(f)


# Line-level regex checks: (regex, predicate(path)->bool, severity, category, title, rec, ver)
def is_js(p):
    return p.endswith('.js')


def is_html(p):
    return p.endswith('.html')


def is_phtml(p):
    return p.endswith('.phtml')


LINE_CHECKS = [
    (re.compile(r'\$\.widget\s*\('), is_js, 'medium', 'jquery-widget',
     'jQuery-UI widget ($.widget) — Breeze runs Cash, not jQuery UI',
     'Port to a Breeze $.widget (breeze-adapt) or enable Better Compatibility.',
     'Load the page on a Breeze theme with ?breeze=1&compat=1 and confirm the widget behaves.'),
    (re.compile(r'\$\.mage\.'), is_js, 'medium', 'jquery-widget',
     'jQuery mage widget ($.mage) usage',
     'Convert to a Breeze widget or enable Better Compatibility for the module.',
     'Verify the behaviour on a Breeze page.'),
    (re.compile(r"'uiComponent'|Magento_Ui/js/"), is_js, 'high', 'knockout',
     'Knockout/uiComponent dependency — Breeze has no Knockout',
     'Rewrite as plain DOM + Cash, or enable Better Compatibility (Knockout-heavy UIs).',
     'Confirm the component renders on a Breeze page.'),
    (re.compile(r'data-bind\s*='), is_html, 'high', 'knockout',
     'Knockout template (data-bind) — Breeze has no Knockout',
     'Replace the KO template with a Breeze widget/template, or use Better Compatibility.',
     'Confirm the markup renders on a Breeze page.'),
    (re.compile(r'(text/x-magento-init|data-mage-init)'), is_phtml, 'info', 'magento-init',
     'data-mage-init / x-magento-init — Breeze supports these',
     'Usually works as-is; verify the referenced component resolves under Breeze.',
     'Load the page on a Breeze theme and check the console for init errors.'),
    (re.compile(r'require\s*\(\s*\['), is_phtml, 'medium', 'requirejs',
     'Inline RequireJS require([...]) in a template',
     'Move logic into a Breeze widget or enable Better Compatibility.',
     'Verify on a Breeze page that the inline script runs.'),
]

REG_RX = re.compile(r"ComponentRegistrar::MODULE\s*,\s*['\"]([A-Za-z0-9]+_[A-Za-z0-9]+)['\"]")
REF_RX = re.compile(r'\b([A-Z][A-Za-z0-9]*_[A-Za-z0-9]+)/([\w./-]+)')


def norm(p):
    return p.replace('\\', '/')


def reg_name(d):
    try:
        m = REG_RX.search(open(os.path.join(d, 'registration.php'), encoding='utf-8', errors='replace').read())
    except OSError:
        return None
    return m.group(1) if m else None


# Breeze is storefront-only: adminhtml never renders under Breeze, so it is pruned from the walk.
entries = []  # (root, files)
modules = {}  # module root -> registered name
for root, dirs, files in os.walk(target):
    dirs[:] = sorted(d for d in dirs if d != 'adminhtml')
    if 'registration.php' in files:
        modules[root] = reg_name(root)
    entries.append((root, sorted(files)))
if not modules:
    modules[target] = None
names = {n for n in modules.values() if n}


def module_of(path):
    best = target
    for r in modules:
        if (path == r or path.startswith(r + os.sep)) and len(r) >= len(best):
            best = r
    return best


def is_breeze_module(r):
    n = modules.get(r) or ''
    b = os.path.basename(r)
    return n.endswith('Breeze') or b.endswith('-breeze') or b.endswith('Breeze')


def sibling_adapter(r):
    # <pkg>-breeze (composer layout) or <Module>Breeze (app/code layout), or a scanned <Name>Breeze.
    parent, b = os.path.dirname(r), os.path.basename(r)
    for cand in (b + '-breeze', b + 'Breeze'):
        d = os.path.join(parent, cand)
        if os.path.isfile(os.path.join(d, 'registration.php')):
            return reg_name(d) or cand
    n = modules.get(r)
    if n and n + 'Breeze' in names:
        return n + 'Breeze'
    return None


def checkout_refs(r):
    # Files wired into checkout_index_index jsLayout: Breeze keeps Luma checkout (RequireJS + KO).
    out = set()
    n = modules.get(r)
    lay = os.path.join(r, 'view', 'frontend', 'layout', 'checkout_index_index.xml')
    if not n or not os.path.isfile(lay):
        return out
    for mod, rest in REF_RX.findall(open(lay, encoding='utf-8', errors='replace').read()):
        if mod != n:
            continue
        for area in ('frontend', 'base'):
            web = os.path.join(r, 'view', area, 'web')
            out.add(norm(os.path.join(web, rest + '.js')))
            out.add(norm(os.path.join(web, 'template', rest + '.html')))
            out.add(norm(os.path.join(web, rest + '.html')))
    return out


state = {}
for r in list(modules) + ([] if target in modules else [target]):  # target: files outside any module
    state[r] = {'assets': False, 'self_adapter': False, 'breeze': is_breeze_module(r),
                'sibling': sibling_adapter(r), 'checkout': checkout_refs(r)}

for root, files in entries:
    nroot = norm(root) + '/'
    mr = module_of(root)
    st = state[mr]
    if '/view/frontend/web/' in nroot:
        st['assets'] = True
    if '/web/css/breeze/' in nroot or '/web/js/breeze/' in nroot:
        st['self_adapter'] = True
    if any(n.startswith('breeze_') and n.endswith('.xml') for n in files):
        st['self_adapter'] = True

for r, st in state.items():
    st['adapter'] = st['sibling'] or ('this module' if st['self_adapter'] else None)

for root, files in entries:
    mr = module_of(root)
    st = state[mr]
    # A Breeze adapter's own files (Cash $.widget etc.) are the fix, not the problem.
    if st['breeze'] or '/breeze/' in norm(root) + '/':
        continue
    for name in files:
        path = os.path.join(root, name)
        rel = path
        npath = norm(path)
        # File-level: requirejs-config.js
        if name == 'requirejs-config.js':
            try:
                content = open(path, encoding='utf-8', errors='replace').read()
            except OSError:
                content = ''
            if re.search(r'mixins', content):
                add('high', 'mixin',
                    'RequireJS mixins declared — Breeze does not load Luma mixins by default',
                    rel, 1,
                    'Re-implement the behaviour as a Breeze widget, or enable Better Compatibility.',
                    'Confirm the mixin behaviour on a Breeze page with ?breeze=1&compat=1.')
            elif st['adapter']:
                add('info', 'requirejs',
                    f"requirejs-config.js present — Breeze adapter {st['adapter']} covers the storefront",
                    rel, 1,
                    'No action if the adapter ports every registered component; otherwise extend it.',
                    'Load a Breeze page and confirm the components initialise.')
            else:
                add('medium', 'requirejs',
                    'requirejs-config.js present — RequireJS is not loaded by Breeze',
                    rel, 1,
                    'Port the registered components to Breeze widgets or enable Better Compatibility.',
                    'Load a Breeze page and confirm the components initialise.')
        # Line-level checks
        if not (is_js(name) or is_html(name) or is_phtml(name)):
            continue
        checkout = '/web/template/checkout/' in npath or npath in st['checkout']
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                for lineno, text in enumerate(fh, start=1):
                    for rx, pred, sev, cat, title, rec, ver in LINE_CHECKS:
                        if pred(name) and rx.search(text):
                            if checkout and cat == 'knockout':
                                add('info', cat, title + ' (checkout: Breeze keeps the Luma checkout, Knockout loads there)',
                                    rel, lineno, 'Usually no action; verify the step on the Breeze store checkout.', ver)
                            else:
                                add(sev, cat, title, rel, lineno, rec, ver)
        except OSError:
            continue

# Module ships frontend assets but has no Breeze adapter yet.
for r, st in state.items():
    if not st['assets'] or st['breeze'] or st['self_adapter']:
        continue
    if st['sibling']:
        add('info', 'assets',
            f"Module ships frontend assets; Breeze adapter {st['sibling']} found",
            r, 1,
            'No action; keep the adapter in step with this module\'s storefront assets.',
            'Spot-check the module\'s storefront pages on a Breeze theme.')
    else:
        add('info', 'assets',
            'Module ships frontend assets but has no Breeze adapter (no breeze_* layout, no web/css/breeze)',
            r, 1,
            'Generate a Breeze companion module with breeze-adapt.',
            'Re-run this audit after adapting; the finding should clear.')

print(json.dumps(findings, indent=2))
PY
