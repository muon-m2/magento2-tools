#!/usr/bin/env bash
# Runs the read-only surface extractor against the fixture module and asserts the
# surface-JSON contract: existing keys plus the multi-doc expansion keys.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

FIXTURE="tests/fixtures/docs-generate/Acme/Sample"
SCRIPT="skills/magento2-docs-generate/scripts/extract-surface.sh"
[ -d "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

# Pre-create a stable output path so the extractor does not place the JSON inside
# its own temp dir (which it removes on EXIT before we can read it).
_SF="$(mktemp /tmp/surface-test-XXXXXX.json)"
trap 'rm -f "$_SF"' EXIT

JSON_PATH="$(MODULE_PATH="$FIXTURE" SURFACE_FILE="$_SF" bash "$SCRIPT")" || { echo "FAIL: extractor errored"; exit 1; }

python3 - "$JSON_PATH" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["surfaces"]
def need(cond, msg):
    if not cond:
        print("FAIL:", msg); sys.exit(1)
# existing-key regression guard
for k in ("api","events_observed","plugins","rest_routes","graphql","db_schema"):
    need(k in s, f"missing existing key {k}")
need(len(s["rest_routes"]) == 2, "expected 2 REST routes")
print("PASS")
PY
