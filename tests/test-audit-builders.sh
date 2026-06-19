#!/usr/bin/env bash
# End-to-end fixture for the two audit builders: security and performance.
# Each must produce:
#   - {OUTPUT_BASENAME}.json   with skill name, outputKind, scanner_errors[], findings[]
#   - {OUTPUT_BASENAME}.sarif  parseable as JSON with SARIF schemaVersion=2.1.0
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/app/code"
cd "$WORK"

run_builder() {
    local skill="$1" expected_skill="$2" expected_kind="$3" expected_basename="$4"
    local script="$OLDPWD/skills/${skill}/scripts/build-findings.sh"
    local outdir="${WORK}/${skill}-out"
    rm -rf "$outdir"

    TARGET_MODULE="Acme_Test" TARGET_PATH="src/app/code/Acme/Test" SCOPE="module" \
        SCAN_ROOT="src/app/code" COMPOSER_LOCK="/dev/null" OUTPUT_DIR="$outdir" \
        bash "$script" > /dev/null 2> "$outdir.err"

    local json="$outdir/${expected_basename}.json"
    local sarif="$outdir/${expected_basename}.sarif"

    if [ ! -f "$json" ]; then
        echo "FAIL: ${skill} did not produce ${json}"
        cat "$outdir.err"
        return 1
    fi
    if [ ! -f "$sarif" ]; then
        echo "FAIL: ${skill} did not produce ${sarif}"
        return 1
    fi

    # Validate JSON shape and skill/kind labels.
    python3 - "$json" "$expected_skill" "$expected_kind" <<'PY'
import json
import sys

path, expected_skill, expected_kind = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as fh:
    d = json.load(fh)

assert d.get('skill') == expected_skill, f"skill={d.get('skill')!r} != {expected_skill!r}"
assert d.get('outputKind') == expected_kind, f"outputKind={d.get('outputKind')!r} != {expected_kind!r}"
assert isinstance(d.get('findings'), list), 'findings should be a list'
assert 'scanner_errors' in d, 'scanner_errors field missing'
assert isinstance(d['scanner_errors'], list), 'scanner_errors should be a list'
sys.exit(0)
PY
    if [ "$?" != "0" ]; then
        echo "FAIL: ${skill} JSON did not match contract"
        return 1
    fi

    # SARIF shape: top-level object with version=2.1.0 and runs[] array.
    python3 - "$sarif" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as fh:
    d = json.load(fh)

assert d.get('version') == '2.1.0', f"SARIF version={d.get('version')!r}"
assert isinstance(d.get('runs'), list) and len(d['runs']) >= 1, 'SARIF must have at least one run'
run = d['runs'][0]
assert 'tool' in run, 'SARIF run must have tool'
assert 'results' in run, 'SARIF run must have results array'
sys.exit(0)
PY
    if [ "$?" != "0" ]; then
        echo "FAIL: ${skill} SARIF did not match contract"
        return 1
    fi

    return 0
}

DATE="$(date -u +%Y-%m-%d)"
FAIL=0

run_builder magento2-security-audit "magento2-security-audit" "security" "security-module-${DATE}" || FAIL=1
run_builder magento2-performance-audit "magento2-performance-audit" "performance" "perf-module-${DATE}" || FAIL=1
run_builder magento2-static-analysis "magento2-static-analysis" "quality" "quality-module-${DATE}" || FAIL=1

cd "$OLDPWD"
exit "$FAIL"
