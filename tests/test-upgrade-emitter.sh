#!/usr/bin/env bash
# test-upgrade-emitter.sh — magento2-module-upgrade must emit BOTH a schema-valid JSON
# document AND a SARIF sibling via the shared hub emitter (regression guard for Proposal 3:
# the skill previously wrote JSON only, with no SARIF, so its findings could not feed CI /
# GitHub Code Scanning like the other findings skills).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

SCRIPT="skills/magento2-module-upgrade/scripts/emit-report.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A representative upgrade findings array (deprecation + bc_break categories).
cat > "$WORK/findings.json" <<'JSON'
[
  {
    "id": "UPG-001",
    "severity": "high",
    "category": "bc_break",
    "title": "Constructor signature changed in Magento\\Framework\\App\\Http",
    "description": "Third argument removed in 2.4.7.",
    "evidence": [{"file": "src/app/code/Acme/Foo/Plugin/HttpPlugin.php", "line": 22}]
  },
  {
    "id": "UPG-002",
    "severity": "medium",
    "category": "deprecation",
    "title": "getResourceCollection() is deprecated",
    "evidence": [{"file": "src/app/code/Acme/Foo/Model/Foo.php", "line": 40}]
  }
]
JSON

BASENAME="Acme_Foo-2.4.5-to-2.4.7-1970-01-01"

FINDINGS_FILE="$WORK/findings.json" \
TARGET_MODULE="Acme_Foo" \
TARGET_PATH="src/app/code/Acme/Foo" \
OUTPUT_BASENAME="$BASENAME" \
OUTPUT_DIR="$WORK/out" \
    bash "$SCRIPT" > /dev/null 2> "$WORK/err" || {
    echo "FAIL: emit-report.sh exited non-zero:"; sed 's/^/    /' "$WORK/err" >&2; exit 1; }

JSON_OUT="$WORK/out/${BASENAME}.json"
SARIF_OUT="$WORK/out/${BASENAME}.sarif"

[ -f "$JSON_OUT" ]  || { echo "FAIL: expected JSON at $JSON_OUT";  exit 1; }
[ -f "$SARIF_OUT" ] || { echo "FAIL: expected SARIF at $SARIF_OUT (module-upgrade must emit SARIF)"; exit 1; }

python3 - "$JSON_OUT" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    d = json.load(fh)
assert d.get('skill') == 'magento2-module-upgrade', f"skill={d.get('skill')!r}"
assert d.get('outputKind') == 'upgrade', f"outputKind={d.get('outputKind')!r}"
assert isinstance(d.get('findings'), list) and len(d['findings']) == 2, 'findings should carry both inputs'
assert 'scanner_errors' in d, 'scanner_errors field missing (schema requires it)'
PY
[ "$?" = "0" ] || { echo "FAIL: module-upgrade JSON did not match contract"; exit 1; }

python3 - "$SARIF_OUT" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    d = json.load(fh)
assert d.get('version') == '2.1.0', f"SARIF version={d.get('version')!r}"
assert isinstance(d.get('runs'), list) and d['runs'], 'SARIF must have a run'
assert d['runs'][0]['tool']['driver']['name'] == 'magento2-module-upgrade', 'SARIF driver name'
assert len(d['runs'][0]['results']) == 2, 'SARIF results should mirror findings'
PY
[ "$?" = "0" ] || { echo "FAIL: module-upgrade SARIF did not match contract"; exit 1; }

echo "upgrade emitter: JSON + SARIF produced and schema-valid"
exit 0
