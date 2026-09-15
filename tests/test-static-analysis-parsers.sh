#!/usr/bin/env bash
# test-static-analysis-parsers.sh — run-analysis.sh must actually PARSE what each tool emits, and
# must surface a tool's stderr rather than swallowing it.
#
# Regression test for a false clean: all three tool passes failed independently and the document
# still reported `findings: []` with `scanner_errors: []`, which is indistinguishable from a pass.
#   * phpcs  — PHP_CodeSniffer prints "DEPRECATED: ..." to STDOUT ahead of the --report=json
#              payload, so json.load() failed and the parser fell back to [].
#   * phpmd  — the parser read a top-level "violations" key that PHPMD does not emit (the real
#              shape nests violations under "files"), so the loop ran zero times and the JSON
#              still parsed cleanly — no error raised anywhere.
#   * phpstan — on a crash it returns files: [] (a LIST), and .values() on that raised an
#              uncaught AttributeError; the crash text in "errors" was discarded.
# The three were invisible because run-analysis.sh wrote each tool's stderr to a temp file it
# never forwarded, and that stderr is the ONLY channel build-findings.sh turns into scanner_errors.
#
# Also locks the calibration that turning the parsers back ON made load-bearing:
#   * a phpmd finding never reaches a BLOCKING severity (audit fails its verdict on
#     critical AND high alike, so "not critical" is not enough — priority 1 caps at medium);
#   * a module that ships phpmd.xml is judged by its own rules, and that is recorded as provenance.
# Pass 2 covers the success shapes, so the crash-path type guard cannot cost us a healthy run.
#
# Tools are stubbed, so this runs without phpcs/phpstan/phpmd installed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

SCRIPT="skills/lint/scripts/run-analysis.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"; MOD="$WORK/module"; mkdir -p "$BIN" "$MOD/etc"

cat > "$MOD/etc/module.xml" <<'XML'
<?xml version="1.0"?>
<config><module name="Acme_Foo"/></config>
XML
printf '<?php\n' > "$MOD/registration.php"

# --- stub phpcs: deprecation preamble on STDOUT, then the real JSON report -------------------
cat > "$BIN/phpcs" <<'STUB'
#!/usr/bin/env bash
echo "DEPRECATED: Support for custom tokenizers will be removed in PHP_CodeSniffer 4.0."
echo "The Magento2.GraphQL.ValidFieldName sniff is listening for GRAPHQL."
cat <<'JSON'
{"totals":{"errors":1,"warnings":1,"fixable":0},"files":{"/m/A.php":{"errors":1,"warnings":1,"messages":[
{"message":"Real error here","source":"Magento2.Legacy.Sniff","severity":5,"fixable":false,"type":"ERROR","line":12,"column":1},
{"message":"Real warning here","source":"Magento2.Annotation.Sniff","severity":5,"fixable":false,"type":"WARNING","line":30,"column":1}]}}}
JSON
exit 1
STUB

# --- stub phpmd: violations nested under files (the real 2.x renderer shape) -----------------
# CamelCaseMethodName at priority 1 is the exact motivating case: PHPMD ships its CamelCase* rules
# at priority 1, and `_resetState()` is NAMED that way because ResetAfterRequestInterface mandates
# it. Echoes its argv so the ruleset-selection assertions can read what it was handed.
#
# The deprecation lines ahead of the JSON are real PHP 8.5 output. With PHP's built-in defaults
# (display_errors=1, error_reporting=E_ALL — what a php-cli container without a php.ini runs),
# pdepend's `(integer)` casts print on STDOUT before the document. Measured in a Magento 2.4.9 /
# PHP 8.5.8 container; the parser used to fail on it and record the pass only as a scanner_errors
# line, so every PHPMD violation was lost.
cat > "$BIN/phpmd" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${PHPMD_ARGV_FILE:-/dev/null}"
cat <<'PRE'

Deprecated: Non-canonical cast (integer) is deprecated, use the (int) cast instead in /var/www/magento/vendor/phpmd/phpmd/src/main/php/PHPMD/RuleSetFactory.php on line 388

Deprecated: Non-canonical cast (integer) is deprecated, use the (int) cast instead in /var/www/magento/vendor/pdepend/pdepend/src/main/php/PDepend/Util/Configuration.php on line 102
PRE
cat <<'JSON'
{"version":"2.15.0","package":"phpmd","files":[{"file":"/m/A.php","violations":[
{"beginLine":43,"endLine":43,"rule":"CamelCaseMethodName","ruleset":"Naming Rules","priority":1,
 "description":"The method _resetState is not named in camelCase."}]}]}
JSON
exit 2
STUB

# --- stub phpstan: a CRASHED run — files is a LIST, with the reason in "errors" --------------
cat > "$BIN/phpstan" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"totals":{"errors":1,"file_errors":0},"files":[],
 "errors":["Child process error: PHPStan process crashed because it reached configured PHP memory limit: 128M"]}
JSON
exit 1
STUB

chmod +x "$BIN/phpcs" "$BIN/phpmd" "$BIN/phpstan"

FINDINGS="$WORK/findings.json"
ERRLOG="$WORK/stderr.txt"
PHPMD_ARGV="$WORK/phpmd-argv.txt"

PHPMD_ARGV_FILE="$PHPMD_ARGV" \
TARGET_PATH="$MOD" SCOPE=module RUNNER="" \
PHPCS="$BIN/phpcs" PHPMD="$BIN/phpmd" PHPSTAN="$BIN/phpstan" RECTOR="" \
FINDINGS_FILE="$FINDINGS" \
    bash "$SCRIPT" >/dev/null 2>"$ERRLOG"

[ -f "$FINDINGS" ] || { echo "FAIL: no findings file produced"; exit 1; }

# --- pass 2: the SUCCESS shapes, and a module that ships its own phpmd.xml -------------------
# The failure shapes above are the regression; these are the paths that must keep working, plus
# the ruleset-selection rule. A separate module dir so pass 1 keeps the built-in-ruleset case.
MOD2="$WORK/module2"; mkdir -p "$MOD2/etc"
cp "$MOD/etc/module.xml" "$MOD2/etc/module.xml"
cp "$MOD/registration.php" "$MOD2/registration.php"
cat > "$MOD2/phpmd.xml" <<'XML'
<?xml version="1.0"?>
<ruleset name="Acme"><rule ref="rulesets/codesize.xml"/></ruleset>
XML

# phpstan on a HEALTHY run: "files" is a dict keyed by path, and there is no top-level "errors".
cat > "$BIN/phpstan-ok" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"totals":{"errors":0,"file_errors":1},"files":{"/m/B.php":{"errors":1,"messages":[
{"message":"Method Acme\\Foo::bar() has no return type specified.","line":21,"ignorable":true}]}}}
JSON
exit 1
STUB
chmod +x "$BIN/phpstan-ok"

FINDINGS2="$WORK/findings2.json"
ERRLOG2="$WORK/stderr2.txt"
PHPMD_ARGV2="$WORK/phpmd-argv2.txt"

PHPMD_ARGV_FILE="$PHPMD_ARGV2" \
TARGET_PATH="$MOD2" SCOPE=module RUNNER="" \
PHPCS="" PHPMD="$BIN/phpmd" PHPSTAN="$BIN/phpstan-ok" RECTOR="" \
FINDINGS_FILE="$FINDINGS2" \
    bash "$SCRIPT" >/dev/null 2>"$ERRLOG2"

[ -f "$FINDINGS2" ] || { echo "FAIL: no findings file produced for the success-shape pass"; exit 1; }

RESULT="$(FINDINGS="$FINDINGS" ERRLOG="$ERRLOG" \
          FINDINGS2="$FINDINGS2" ERRLOG2="$ERRLOG2" \
          PHPMD_ARGV2="$PHPMD_ARGV2" MOD2="$MOD2" python3 <<'PY'
import json
import os
import sys

findings = json.load(open(os.environ['FINDINGS'], encoding='utf-8'))
stderr = open(os.environ['ERRLOG'], encoding='utf-8', errors='replace').read()
findings2 = json.load(open(os.environ['FINDINGS2'], encoding='utf-8'))
stderr2 = open(os.environ['ERRLOG2'], encoding='utf-8', errors='replace').read()
fail = []

# audit blocks its verdict on BOTH of these:
#   consolidate.sh → `if sev in ('critical','high'): blockers += 1` → `FAIL if blockers`
BLOCKING = ('critical', 'high')


def by(prefix, source=None):
    return [f for f in (findings if source is None else source)
            if str(f.get('id', '')).startswith(prefix)]


# 1. phpcs — the deprecation preamble must not cost us the report.
phpcs = by('quality-phpcs-')
if len(phpcs) != 2:
    fail.append(f'phpcs: expected 2 findings through the DEPRECATED preamble, got {len(phpcs)}')
elif not any('Real error here' in (f.get('title') or '') for f in phpcs):
    fail.append('phpcs: parsed, but the ERROR message did not survive')

# 2. phpmd — violations nested under files must be read.
phpmd = by('quality-phpmd-')
if len(phpmd) != 1:
    fail.append(f'phpmd: expected 1 finding from the files[].violations[] shape, got {len(phpmd)}')
else:
    ev = (phpmd[0].get('evidence') or [{}])[0]
    if ev.get('file') != '/m/A.php':
        fail.append(f"phpmd: fileName not taken from the parent file key, got {ev.get('file')!r}")
    # 3. A lint rule must never BLOCK a release. Asserting "not critical" is too weak: high blocks
    #    the audit verdict exactly like critical does, so priority 1 must land at most at medium.
    sev = phpmd[0].get('severity')
    if sev in BLOCKING:
        fail.append(f"phpmd: priority 1 graded {sev!r} — a blocking tier; "
                    "CamelCaseMethodName on a mandated _resetState() would FAIL the audit")

# 4. phpstan — a crashed run (files: []) must not raise, and its reason must reach stderr.
if 'memory limit' not in stderr:
    fail.append('phpstan: run-level crash text was not surfaced to stderr')

# 5. stderr is the ONLY channel that becomes scanner_errors — it must carry the tool diagnostics.
if 'run-analysis/phpstan' not in stderr:
    fail.append('tool stderr was not forwarded; scanner_errors would be empty on failure')

# 6. Forwarding must not re-tag a line the parser already tagged.
if 'run-analysis/phpcs: run-analysis/phpcs:' in stderr:
    fail.append('forwarding double-prefixed an already-tagged line')

# --- pass 2: success shapes + module ruleset -------------------------------------------------

# 7. phpstan's healthy shape ("files" as a dict) must still parse — the crash-path type guard
#    must not have cost us the success path.
phpstan_ok = by('quality-phpstan-', findings2)
if len(phpstan_ok) != 1:
    fail.append(f'phpstan: expected 1 finding from the healthy files{{}} dict shape, '
                f'got {len(phpstan_ok)}')
elif 'no return type specified' not in (phpstan_ok[0].get('title') or ''):
    fail.append('phpstan: parsed the dict shape, but the message did not survive')
else:
    # The file path is the dict KEY — phpstan's message objects carry no `file`. Reading one gave
    # '?' for every finding, which strands it: evidence.file is what SARIF anchors a result to.
    # Asserting the message survived is not enough; a finding that points nowhere is not usable.
    ev = (phpstan_ok[0].get('evidence') or [{}])[0]
    if ev.get('file') != '/m/B.php':
        fail.append(f"phpstan: evidence.file is {ev.get('file')!r}, not the files{{}} key — "
                    'the finding cannot be anchored to a file in SARIF')
    if ev.get('line') != 21:
        fail.append(f"phpstan: evidence.line is {ev.get('line')!r}, expected 21")

# 8. A module that ships phpmd.xml must be judged by it, not by the built-in sets.
argv = open(os.environ['PHPMD_ARGV2'], encoding='utf-8').read().splitlines()
expected_ruleset = os.path.join(os.environ['MOD2'], 'phpmd.xml')
if expected_ruleset not in argv:
    fail.append(f'phpmd: module ruleset not passed; argv was {argv!r}')
if any(a.startswith('cleancode,codesize') for a in argv):
    fail.append('phpmd: built-in rulesets used even though the module ships phpmd.xml')

# 9. Using a module's own rules is provenance the report must carry — the findings then reflect
#    the rules that module selected for itself.
if 'own ruleset' not in stderr2:
    fail.append('phpmd: module-ruleset use was not recorded for scanner_errors')

print('\n'.join(fail) if fail else 'OK')
PY
)"

if [ "$RESULT" = "OK" ]; then
    echo "PASS: static-analysis parsers read each tool's real output, cap lint severity below the"
    echo "      audit's blocking tiers, honour a module's own ruleset, and forward tool stderr"
    exit 0
fi

echo "FAIL:"
echo "$RESULT"
echo "--- stderr captured (pass 1: failure shapes) ---"
cat "$ERRLOG"
echo "--- stderr captured (pass 2: success shapes) ---"
cat "$ERRLOG2"
exit 1
