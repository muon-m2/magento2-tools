#!/usr/bin/env bash
# test-emitter-schema-conformance.sh — the emitted findings document MUST carry every
# top-level field that findings-schema.md marks Required. Regression guard for the audit's
# H9 (module-review's emit-json.sh omitted the required `scanner_errors` field, producing a
# schema-invalid document). Driven by the schema doc so it tracks the contract automatically.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

SCHEMA="skills/context/references/findings-schema.md"
EMIT_JSON="skills/context/scripts/emit-json.sh"
FIX_DIR="tests/golden/fixtures"

for f in "$SCHEMA" "$EMIT_JSON" "$FIX_DIR/findings.json" "$FIX_DIR/context.json"; do
    [ -f "$f" ] || { echo "FAIL: required input missing: $f"; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT_JSON="$WORK/out.json"
FAIL=0

# Run the canonical emitter with the same fixed inputs the golden test uses.
FINDINGS_FILE="$FIX_DIR/findings.json" \
CONTEXT_FILE="$FIX_DIR/context.json" \
TARGET_MODULE="Acme_Golden" \
TARGET_PATH="src/app/code/Acme/Golden" \
MODE="full" \
SCOPE="module" \
OUTPUT_KIND="review" \
SKILL_NAME="review" \
SKILL_VERSION="2.3.0" \
SKILL_VERSIONS_JSON='["review@2.3.0","context@1.6.0"]' \
OUTPUT_DIR="$WORK" \
OUTPUT_BASENAME="conf" \
bash "$EMIT_JSON" > "$OUT_JSON" 2>"$WORK/err" || {
    echo "FAIL: emit-json.sh exited non-zero:"; sed 's/^/    /' "$WORK/err" >&2; exit 1; }

python3 - "$SCHEMA" "$OUT_JSON" <<'PY'
import json
import re
import sys

schema_path, out_path = sys.argv[1], sys.argv[2]

# Parse the "Top-Level Fields the Emitter Adds" table for rows marked Required = Yes.
required = []
in_table = False
for line in open(schema_path, encoding="utf-8"):
    if line.startswith("## ") and "Top-Level Fields the Emitter Adds" in line:
        in_table = True
        continue
    if in_table:
        if line.startswith("## "):
            break
        m = re.match(r'\|\s*([A-Za-z_]+)\s*\|\s*Yes\b', line)
        if m:
            required.append(m.group(1))

if not required:
    print(f"FAIL: could not parse any Required=Yes fields from {schema_path}")
    sys.exit(1)

try:
    doc = json.load(open(out_path, encoding="utf-8"))
except (json.JSONDecodeError, OSError) as exc:
    print(f"FAIL: emitter output is not valid JSON: {exc}")
    sys.exit(1)

missing = [f for f in required if f not in doc]
if missing:
    print("FAIL: emitted document missing required schema field(s): " + ", ".join(missing))
    print("  present: " + ", ".join(sorted(doc.keys())))
    sys.exit(1)

print(f"emitter document carries all {len(required)} required top-level fields "
      f"({', '.join(required)})")
sys.exit(0)
PY
PYRC=$?
[ "$PYRC" -eq 0 ] || FAIL=1

# schemaVersion 1.1 — every finding carries a stable fingerprint, and the two
# remediation-cycle output kinds are accepted.
VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["schemaVersion"])' "$OUT_JSON")"
if [ "$VER" != "1.1" ]; then
    echo "FAIL: schemaVersion is '$VER', expected '1.1'"
    FAIL=1
fi

MISSING="$(python3 - "$OUT_JSON" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
bad = [f.get("id", "<no id>") for f in doc.get("findings", [])
       if not isinstance(f.get("fingerprint"), str) or len(f["fingerprint"]) != 64]
print(",".join(bad))
PY
)"
if [ -n "$MISSING" ]; then
    echo "FAIL: findings without a 64-char fingerprint: $MISSING"
    FAIL=1
fi

exit "$FAIL"
