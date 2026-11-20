#!/usr/bin/env bash
# test-lint-test-code-noise.sh — lint must grade phpcs by the type phpcs reported, and must not
# bury a module's real findings under its test code.
#
# Measured on the Muon_Blog* family (28 packages): 4,452 of 4,999 lint findings were in Test/ —
# phpmd complexity on test methods, phpstan "undefined method object::…" on mocks (no
# phpstan-phpunit), phpcs style — while the project's own module gate excludes Test/ from PHPMD
# and fails only on phpcs ERRORs. phpcs WARNINGs were also "medium", indistinguishable from real problems.
#   * phpcs: ERROR → high (unchanged), WARNING → low; a Test/ finding is kept but capped at low.
#   * phpmd: Test/ is excluded from the run (and post-filtered), as the module gate does.
#   * phpstan: Test/ rows are dropped unless the config loads phpstan-phpunit.
#   * what was left out is recorded in `skipped`, so the omission never reads as clean.
#   * LINT_INCLUDE_TESTS=1 restores the old behaviour.
# Controls: a real ERROR/violation/type error OUTSIDE Test/ must still be reported, and a target
# that itself sits under a directory named tests/ must not have its own code treated as test code.
#
# Tools are stubbed, so this runs without phpcs/phpstan/phpmd installed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

RUN="skills/lint/scripts/run-analysis.sh"
BUILD="skills/lint/scripts/build-findings.sh"
for f in "$RUN" "$BUILD"; do [ -f "$f" ] || { echo "FAIL: $f not found"; exit 1; }; done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
WORK="$(cd "$WORK" && pwd -P)"
BIN="$WORK/bin"
# The module sits under a `tests/` directory on purpose: only segments BELOW the target count.
MOD="$WORK/tests/Acme_Foo"
mkdir -p "$BIN" "$MOD/etc" "$MOD/Model" "$MOD/Test/Unit"
printf '<?xml version="1.0"?>\n<config><module name="Acme_Foo"/></config>\n' > "$MOD/etc/module.xml"
printf '<?php\n' > "$MOD/registration.php"
printf '<?php\n' > "$MOD/Model/A.php"
printf '<?php\n' > "$MOD/Test/Unit/ATest.php"

SRC="$MOD/Model/A.php"
TST="$MOD/Test/Unit/ATest.php"

cat > "$BIN/phpcs" <<STUB
#!/usr/bin/env bash
cat <<'JSON'
{"totals":{"errors":2,"warnings":1},"files":{
"$SRC":{"messages":[
{"message":"src error","source":"Magento2.Security.Sniff","fixable":false,"type":"ERROR","line":3},
{"message":"src warning","source":"Magento2.Annotation.Sniff","fixable":false,"type":"WARNING","line":4}]},
"$TST":{"messages":[
{"message":"test error","source":"Magento2.Legacy.Sniff","fixable":false,"type":"ERROR","line":5}]}}}
JSON
exit 1
STUB

cat > "$BIN/phpmd" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "\${PHPMD_ARGV_FILE:-/dev/null}"
cat <<'JSON'
{"files":[
{"file":"$SRC","violations":[{"beginLine":7,"endLine":9,"rule":"CyclomaticComplexity","ruleset":"Code Size Rules","priority":3,"description":"src complexity"}]},
{"file":"$TST","violations":[{"beginLine":7,"endLine":9,"rule":"ExcessiveMethodLength","ruleset":"Code Size Rules","priority":3,"description":"test complexity"}]}]}
JSON
exit 2
STUB

cat > "$BIN/phpstan" <<STUB
#!/usr/bin/env bash
cat <<'JSON'
{"totals":{"errors":0,"file_errors":2},"files":{
"$SRC":{"messages":[{"message":"src type error","line":11,"ignorable":true}]},
"$TST":{"messages":[{"message":"Call to an undefined method object::setId().","line":12,"ignorable":true}]}}}
JSON
exit 1
STUB
chmod +x "$BIN/phpcs" "$BIN/phpmd" "$BIN/phpstan"

PLAIN_NEON="$WORK/plain.neon"
printf 'parameters:\n    level: 8\n' > "$PLAIN_NEON"
PHPUNIT_NEON="$WORK/phpunit.neon"
printf 'includes:\n    - vendor/phpstan/phpstan-phpunit/extension.neon\n' > "$PHPUNIT_NEON"

# run <name> <phpstan-config> [env…] — run-analysis.sh with SKIPPED_FILE + phpmd argv captured.
run() {
    local name="$1" neon="$2"; shift 2
    env "$@" PHPMD_ARGV_FILE="$WORK/$name.argv" SKIPPED_FILE="$WORK/$name.skipped" \
        TARGET_PATH="$MOD" SCOPE=module RUNNER="" PHPSTAN_CONFIG="$neon" \
        PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="$BIN/phpstan" RECTOR="" \
        FINDINGS_FILE="$WORK/$name.json" \
        bash "$RUN" >/dev/null 2>"$WORK/$name.err"
}

run default "$PLAIN_NEON"
run include "$PLAIN_NEON" LINT_INCLUDE_TESTS=1
run phpunit "$PHPUNIT_NEON"

# The document-level contract: build-findings.sh must publish the skip in `skipped`.
DOC_DIR="$WORK/docs"
TARGET_MODULE=Acme_Foo TARGET_PATH="$MOD" SCOPE=module RUNNER="" PHPSTAN_CONFIG="$PLAIN_NEON" \
PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="$BIN/phpstan" RECTOR="" \
DOCS_ROOT="$DOC_DIR" bash "$BUILD" >/dev/null 2>"$WORK/build.err"
TARGET_MODULE=Acme_Foo TARGET_PATH="$MOD" SCOPE=module RUNNER="" PHPSTAN_CONFIG="$PLAIN_NEON" \
PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="$BIN/phpstan" RECTOR="" LINT_INCLUDE_TESTS=1 \
DOCS_ROOT="$WORK/docs-include" bash "$BUILD" >/dev/null 2>"$WORK/build-include.err"

WORK="$WORK" SRC="$SRC" TST="$TST" MOD="$MOD" python3 <<'PY'
import glob
import json
import os
import sys

W, SRC, TST, MOD = (os.environ[k] for k in ('WORK', 'SRC', 'TST', 'MOD'))
passed = 0
failed = []


def check(cond, msg):
    global passed
    if cond:
        passed += 1
    else:
        failed.append(msg)


def load(name):
    return json.load(open(f'{W}/{name}.json', encoding='utf-8'))


def rows(findings, tool, path=None):
    return [f for f in findings if f['id'].startswith(f'quality-{tool}-')
            and (path is None or f['evidence'][0]['file'] == path)]


def sev(findings, title):
    hit = [f for f in findings if f['title'] == title]
    return hit[0]['severity'] if hit else None


d = load('default')
# 1. phpcs severity follows phpcs's own type.
check(sev(d, 'src error') == 'high', f"phpcs ERROR → {sev(d, 'src error')!r}, want high")
check(sev(d, 'src warning') == 'low', f"phpcs WARNING → {sev(d, 'src warning')!r}, want low")
# 2. phpcs on Test/ is kept but capped at low.
check(sev(d, 'test error') == 'low', f"phpcs ERROR in Test/ → {sev(d, 'test error')!r}, want low")
# 3. phpmd: src violation survives (control), Test/ one does not, and Test/ is excluded at the tool.
check(len(rows(d, 'phpmd', SRC)) == 1, 'phpmd: src violation lost (rule silenced entirely?)')
check(not rows(d, 'phpmd', TST), 'phpmd: Test/ violation reported by default')
argv = open(f'{W}/default.argv', encoding='utf-8').read()
check(f'{MOD}/Test/*' in argv, f'phpmd: Test/ not passed to --exclude; argv {argv!r}')
# 4. phpstan: src error survives (control), Test/ mock-type error does not.
check(len(rows(d, 'phpstan', SRC)) == 1, 'phpstan: src error lost')
check(not rows(d, 'phpstan', TST), 'phpstan: Test/ row kept without phpstan-phpunit')
# 5. The target lives under …/tests/ — its own code must not have been classed as test code.
check(sev(d, 'src error') != 'low', 'a tests/ segment ABOVE the target demoted src findings')
# 6. The omission is recorded.
sk = json.load(open(f'{W}/default.skipped', encoding='utf-8'))
checks = ' | '.join(s.get('check', '') for s in sk)
check('phpmd' in checks and 'phpstan' in checks, f'skipped lacks phpmd/phpstan Test/ entries: {sk!r}')
check(all('LINT_INCLUDE_TESTS=1' in s.get('reason', '') for s in sk), f'skipped reason lacks the switch: {sk!r}')

# 7. LINT_INCLUDE_TESTS=1 restores everything.
i = load('include')
check(len(rows(i, 'phpmd')) == 2, 'LINT_INCLUDE_TESTS=1: phpmd Test/ row still dropped')
check(len(rows(i, 'phpstan')) == 2, 'LINT_INCLUDE_TESTS=1: phpstan Test/ row still dropped')
check(sev(i, 'test error') == 'high', 'LINT_INCLUDE_TESTS=1: phpcs Test/ ERROR still capped')
check('/Test/' not in open(f'{W}/include.argv', encoding='utf-8').read(), 'LINT_INCLUDE_TESTS=1: phpmd still excludes Test/')
check(json.load(open(f'{W}/include.skipped', encoding='utf-8')) == [], 'LINT_INCLUDE_TESTS=1: skipped not empty')

# 8. A config that loads phpstan-phpunit is designed to analyse tests: keep its Test/ rows.
p = load('phpunit')
check(len(rows(p, 'phpstan', TST)) == 1, 'phpstan-phpunit config: Test/ rows dropped anyway')
psk = ' | '.join(s.get('check', '') for s in json.load(open(f'{W}/phpunit.skipped', encoding='utf-8')))
check('phpstan' not in psk, 'phpstan-phpunit config: phpstan still listed as skipped')

# 9. build-findings.sh publishes the skip in the document.
docs = glob.glob(f'{W}/docs/quality/*.json')
check(len(docs) == 1, f'build-findings: expected 1 document, got {docs}')
if docs:
    doc = json.load(open(docs[0], encoding='utf-8'))
    check(any('phpmd' in s.get('check', '') for s in doc.get('skipped', [])),
          f"document `skipped` lacks the Test/ exclusion: {doc.get('skipped')!r}")
    check(len(doc['findings']) == 5, f"document carries {len(doc['findings'])} findings, want 5")
docs_i = glob.glob(f'{W}/docs-include/quality/*.json')
if docs_i:
    check(json.load(open(docs_i[0], encoding='utf-8')).get('skipped') == [],
          'build-findings LINT_INCLUDE_TESTS=1: skipped not empty')
else:
    check(False, 'build-findings LINT_INCLUDE_TESTS=1: no document')

if failed:
    print(f'FAIL: {len(failed)} failed, {passed} passed')
    for m in failed:
        print('  - ' + m)
    sys.exit(1)
print(f'PASS: {passed} checks — phpcs graded by type, Test/ noise excluded/capped and recorded in skipped')
PY
