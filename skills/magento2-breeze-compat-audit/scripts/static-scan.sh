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
     'Port to a Breeze $.widget (magento2-breeze-module-adapt) or enable Better Compatibility.',
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

has_frontend_assets = False
has_breeze_layout = False
has_breeze_css = False

for root, dirs, files in os.walk(target):
    if '/view/frontend/web' in root.replace('\\', '/'):
        has_frontend_assets = True
    if root.replace('\\', '/').endswith('/web/css/breeze') or '/web/css/breeze/' in root.replace('\\', '/') + '/':
        has_breeze_css = True
    for name in files:
        path = os.path.join(root, name)
        rel = path
        if name.startswith('breeze_') and name.endswith('.xml'):
            has_breeze_layout = True
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
            else:
                add('medium', 'requirejs',
                    'requirejs-config.js present — RequireJS is not loaded by Breeze',
                    rel, 1,
                    'Port the registered components to Breeze widgets or enable Better Compatibility.',
                    'Load a Breeze page and confirm the components initialise.')
        # Line-level checks
        if not (is_js(name) or is_html(name) or is_phtml(name)):
            continue
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                for lineno, text in enumerate(fh, start=1):
                    for rx, pred, sev, cat, title, rec, ver in LINE_CHECKS:
                        if pred(name) and rx.search(text):
                            add(sev, cat, title, rel, lineno, rec, ver)
        except OSError:
            continue

# Module ships frontend assets but has no Breeze adapter yet.
if has_frontend_assets and not has_breeze_layout and not has_breeze_css:
    add('info', 'assets',
        'Module ships frontend assets but has no Breeze adapter (no breeze_* layout, no web/css/breeze)',
        target, 1,
        'Generate a Breeze companion module with magento2-breeze-module-adapt.',
        'Re-run this audit after adapting; the finding should clear.')

print(json.dumps(findings, indent=2))
PY
