#!/usr/bin/env bash
# run-analysis.sh must actually scan the code it is pointed at — including code that lives under a
# directory named var/ or vendor/ — and must say so when a scanner looked at nothing.
#
# Regression test for a false clean measured in a Magento 2.4.9 container. The exclude list was a
# set of free-floating globs, `*/vendor/*,*/generated/*,*/var/*,*/pub/static/*`:
#   * PHP_CodeSniffer matches --ignore as an UNANCHORED regex against each file's realpath, so
#     `*/var/*` matched every file under the image's install root /var/www/magento, and `*/vendor/*`
#     matched every file of a Composer-installed module. phpcs scanned 0 files; 23 once anchored.
#   * PHPMD (pdepend's ExcludePathFilter) tests the same patterns ^-anchored against the realpath,
#     so it scanned nothing either.
# Both tools emitted an empty report, which parsed to 0 findings — indistinguishable from a clean
# module — and the document's `tools` map was `{}`, so nothing recorded what had run.
#
# Also covers the default output path: run-analysis.sh and surface-invariants.sh printed a
# FINDINGS_FILE inside a temp dir their own EXIT trap removed.
#
# The scanners are stubbed with each tool's real matching rule, so no phpcs or phpmd is needed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

SCRIPTS="$PWD/skills/lint/scripts"
[ -f "$SCRIPTS/run-analysis.sh" ] || { echo "FAIL: $SCRIPTS/run-analysis.sh not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/cwd" "$WORK/tmp" "$WORK/out"

# --- stub phpcs --------------------------------------------------------------------------------
cat > "$BIN/phpcs" <<'STUB'
#!/usr/bin/env python3
"""phpcs stand-in. Applies --ignore the way PHP_CodeSniffer 3.x Filter::shouldIgnorePath does for
command-line patterns: `*` becomes `.*`, and the result is an UNANCHORED, case-insensitive regex
tested against the file's realpath. Reports one warning per scanned file, so findings == files
scanned, and — like the real JSON report — lists nothing when nothing was scanned."""
import json, os, re, sys

ignores, targets = [], []
for arg in sys.argv[1:]:
    if arg.startswith('--ignore='):
        ignores += [p for p in arg[len('--ignore='):].split(',') if p]
    elif not arg.startswith('-'):
        targets.append(arg)
patterns = [re.compile(p.replace('*', '.*'), re.I) for p in ignores]

files = {}
if os.environ.get('STUB_PHPCS_SCANS_NOTHING') != '1':
    for target in targets:
        for dirpath, _dirs, names in os.walk(os.path.realpath(target)):
            for name in names:
                full = os.path.join(dirpath, name)
                if name.endswith(('.php', '.phtml')) and not any(p.search(full) for p in patterns):
                    files[full] = {'errors': 0, 'warnings': 1, 'messages': [{
                        'message': 'stub: file was scanned', 'source': 'Stub.Scanned.File',
                        'severity': 5, 'fixable': False, 'type': 'WARNING', 'line': 1, 'column': 1}]}
print(json.dumps({'totals': {'errors': 0, 'warnings': len(files), 'fixable': 0}, 'files': files}))
sys.exit(1 if files else 0)
STUB

# --- stub phpmd --------------------------------------------------------------------------------
cat > "$BIN/phpmd" <<'STUB'
#!/usr/bin/env python3
"""phpmd stand-in. Applies --exclude the way pdepend's ExcludePathFilter does: every pattern is
preg_quote'd with its quoted star turned back into `.*`, then tested UNANCHORED against the path
local to the target AND ^-ANCHORED against the realpath; either match excludes the file. Reports
one violation per scanned file."""
import json, os, re, sys

excludes, positional = [], []
for arg in sys.argv[1:]:
    if arg.startswith('--exclude='):
        excludes += [p for p in arg.split('=', 1)[1].split(',') if p]
    elif not arg.startswith('-'):
        positional.append(arg)
target = positional[0]
quoted = '|'.join(re.escape(p).replace(r'\*', '.*') for p in excludes)
relative = re.compile('(%s)' % quoted, re.I) if quoted else None
absolute = re.compile('^(%s)' % quoted, re.I) if quoted else None

report = []
for dirpath, _dirs, names in os.walk(target):
    for name in names:
        if not name.endswith('.php'):
            continue
        full = os.path.realpath(os.path.join(dirpath, name))
        local = full[len(target):] if full.startswith(target) else full
        if relative and (relative.search(local) or absolute.match(full)):
            continue
        report.append({'file': full, 'violations': [{
            'beginLine': 1, 'endLine': 1, 'rule': 'StubScannedFile', 'ruleset': 'Stub Rules',
            'priority': 3, 'description': 'stub: file was scanned'}]})
print(json.dumps({'version': '2.15.0', 'package': 'phpmd', 'files': report}, indent=2))
sys.exit(2 if report else 0)
STUB

chmod +x "$BIN/phpcs" "$BIN/phpmd"

# --- fixture: a Docker image's install root with a Composer-installed module inside it ---------
# The module has BOTH ancestors the old globs matched: var/ (install root /var/www/magento) and
# vendor/ (where Composer puts it). It also carries its OWN vendor/ — a dev-package after
# `composer install` — which must still be excluded.
ROOT="$WORK/var/www/magento"
MOD="$ROOT/vendor/acme/module-probe"
mkdir -p "$MOD/etc" "$MOD/Model" "$MOD/view/frontend/templates" "$MOD/vendor/lib" \
    "$ROOT/app/code/Acme/Local/Model" "$ROOT/var/cache" "$ROOT/generated/code" "$ROOT/pub/static"
for f in "$MOD/registration.php" "$MOD/Model/Thing.php" "$MOD/view/frontend/templates/thing.phtml" \
    "$MOD/vendor/lib/Inner.php" "$ROOT/app/code/Acme/Local/Model/Local.php" \
    "$ROOT/var/cache/Cached.php" "$ROOT/generated/code/Generated.php" "$ROOT/pub/static/Static.php"
do
    printf '<?php\n' > "$f"
done
printf '<?xml version="1.0"?>\n<config><module name="Acme_Probe"/></config>\n' > "$MOD/etc/module.xml"

NOPHP="$WORK/no-php/Acme/Empty"
mkdir -p "$NOPHP/etc"
cp "$MOD/etc/module.xml" "$NOPHP/etc/module.xml"

# Every scanner runs from an empty cwd, so the vendor/bin probes find no phpstan and no rector.
analyse() {
    local label="$1"; shift
    (cd "$WORK/cwd" && env "$@" RUNNER="" PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="" RECTOR="" \
        TMPDIR="$WORK/tmp" bash "$SCRIPTS/run-analysis.sh") >"$WORK/$label.stdout" 2>"$WORK/$label.stderr"
}

# 1. module scope — the module sits under a var/ AND a vendor/ ancestor.
analyse module TARGET_PATH="$MOD" SCOPE=module \
    FINDINGS_FILE="$WORK/module.json" TOOLS_FILE="$WORK/module.tools.json"
# 2. site scope from the install root — vendor/, generated/, var/, pub/static/ excluded, and only those.
analyse site TARGET_PATH="$ROOT" SCOPE=site \
    FINDINGS_FILE="$WORK/site.json" TOOLS_FILE="$WORK/site.tools.json"
# 3. a scanner that looked at nothing although the target has PHP files — never a clean result.
analyse zero TARGET_PATH="$MOD" SCOPE=module STUB_PHPCS_SCANS_NOTHING=1 \
    FINDINGS_FILE="$WORK/zero.json" TOOLS_FILE="$WORK/zero.tools.json"
# 4. …while a target with no PHP at all legitimately scans 0 files.
analyse nophp TARGET_PATH="$NOPHP" SCOPE=module \
    FINDINGS_FILE="$WORK/nophp.json" TOOLS_FILE="$WORK/nophp.tools.json"

# 5. end to end — the zero scan must reach the emitted document's scanner_errors and tools map.
(cd "$WORK/cwd" && env STUB_PHPCS_SCANS_NOTHING=1 TARGET_MODULE=Acme_Probe TARGET_PATH="$MOD" SCOPE=module \
    OUTPUT_DIR="$WORK/out" RUNNER="" PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="" RECTOR="" \
    TMPDIR="$WORK/tmp" bash "$SCRIPTS/build-findings.sh") >"$WORK/doc.stdout" 2>"$WORK/doc.stderr"

# 6. the DEFAULT output path (FINDINGS_FILE unset) must still exist once each script has exited.
DEFAULT_RUN="$(cd "$WORK/cwd" && env -u FINDINGS_FILE TARGET_PATH="$MOD" SCOPE=module RUNNER="" \
    PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="" RECTOR="" TMPDIR="$WORK/tmp" \
    bash "$SCRIPTS/run-analysis.sh" 2>/dev/null)"
DEFAULT_SI="$(cd "$WORK/cwd" && env -u FINDINGS_FILE TARGET_PATH="$MOD" TMPDIR="$WORK/tmp" \
    bash "$SCRIPTS/surface-invariants.sh" 2>/dev/null)"

RESULT="$(WORK="$WORK" ROOT="$ROOT" DEFAULT_RUN="$DEFAULT_RUN" DEFAULT_SI="$DEFAULT_SI" python3 <<'PY'
import glob
import json
import os

W, ROOT = os.environ['WORK'], os.path.realpath(os.environ['ROOT'])
fail = []


def load(path, default):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except Exception as exc:
        fail.append(f'{os.path.relpath(path, W)}: not readable JSON ({exc})')
        return default


def scanned(findings, tool):
    out = set()
    for f in findings:
        if str(f.get('id', '')).startswith(f'quality-{tool}-'):
            path = os.path.realpath((f.get('evidence') or [{}])[0].get('file', ''))
            out.add(os.path.relpath(path, ROOT))
    return out


def text(name):
    with open(os.path.join(W, name), encoding='utf-8', errors='replace') as fh:
        return fh.read()


# 1. module scope
PROBE = 'vendor/acme/module-probe/'
module = load(f'{W}/module.json', [])
want = {PROBE + 'registration.php', PROBE + 'Model/Thing.php', PROBE + 'view/frontend/templates/thing.phtml'}
got = scanned(module, 'phpcs')
if got != want:
    fail.append(f'module scope: phpcs scanned {sorted(got)}, expected {sorted(want)}')
want = {PROBE + 'registration.php', PROBE + 'Model/Thing.php'}
got = scanned(module, 'phpmd')
if got != want:
    fail.append(f'module scope: phpmd scanned {sorted(got)}, expected {sorted(want)}')
tools = load(f'{W}/module.tools.json', {})
for tool, status in (('phpcs', 'executed'), ('phpmd', 'executed'),
                     ('phpstan', 'unavailable'), ('rector', 'unavailable')):
    if tools.get(tool) != status:
        fail.append(f'module scope: tools[{tool!r}] is {tools.get(tool)!r}, expected {status!r}')
if 'surface-invariants' not in tools:
    fail.append(f'module scope: tools has no surface-invariants entry: {tools!r}')

# 2. site scope
site = load(f'{W}/site.json', [])
want = {'app/code/Acme/Local/Model/Local.php'}
for tool in ('phpcs', 'phpmd'):
    got = scanned(site, tool)
    if got != want:
        fail.append(f'site scope: {tool} scanned {sorted(got)}, expected {sorted(want)}')
if load(f'{W}/site.tools.json', {}).get('surface-invariants') != 'skipped':
    fail.append('site scope: surface-invariants (module-only) not recorded as skipped')

# 3. zero scan
if 'scanned 0 files' not in text('zero.stderr'):
    fail.append('zero scan: phpcs looked at nothing and no scanner error said so')
if load(f'{W}/zero.tools.json', {}).get('phpcs') != 'degraded':
    fail.append('zero scan: tools["phpcs"] is not "degraded"')

# 4. no PHP at all
if 'scanned 0 files' in text('nophp.stderr'):
    fail.append('no-PHP target: a legitimately empty scan was flagged as degraded')
if load(f'{W}/nophp.tools.json', {}).get('phpcs') != 'executed':
    fail.append('no-PHP target: tools["phpcs"] is not "executed"')

# 5. the emitted document
docs = glob.glob(f'{W}/out/*.json')
if len(docs) != 1:
    fail.append(f'build-findings: expected one JSON document, found {docs}')
else:
    doc = load(docs[0], {})
    if not any('scanned 0 files' in (e.get('stderr') or '') for e in doc.get('scanner_errors') or []):
        fail.append(f"document: zero scan missing from scanner_errors: {doc.get('scanner_errors')!r}")
    if (doc.get('tools') or {}).get('phpcs') != 'degraded':
        fail.append(f"document: tools is {doc.get('tools')!r}, expected phpcs 'degraded'")

# 6. default output paths
for label, path in (('run-analysis.sh', os.environ['DEFAULT_RUN']),
                    ('surface-invariants.sh', os.environ['DEFAULT_SI'])):
    if not path or not os.path.isfile(path):
        fail.append(f'{label}: printed output path does not exist once the script exits: {path!r}')
    else:
        load(path, None)

print('\n'.join(fail) if fail else 'OK')
PY
)"

if [ "$RESULT" = "OK" ]; then
    echo "PASS: lint scans code under var/ and vendor/ ancestors, flags a zero-file scan, records"
    echo "      per-scanner status in tools, and leaves its default output file in place"
    exit 0
fi

echo "FAIL:"
echo "$RESULT"
for f in module zero doc; do echo "--- $f.stderr ---"; cat "$WORK/$f.stderr"; done
exit 1
