#!/usr/bin/env bash
# build-findings.sh — aggregate performance scanner output into one findings JSON, then
# emit the unified document via the shared emit-json.sh pipeline (skill-labelled as
# magento2-performance-audit, output kind "performance"). Also emits SARIF.
#
# Structurally identical to magento2-security-audit/scripts/build-findings.sh so the two
# audit skills share one mental model.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderS3Export" or "site"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderS3Export" or "."
#   SCOPE               "module" | "site"  (default: module)
#   SCAN_ROOT           default: src/app/code
#   INCLUDE_RUNTIME     "1" to include runtime-checks.sh output (default: off)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See magento2-context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/audits
#   SKILL_VERSION       default: 1.2.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-perf-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/perf-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes the JSON.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
INCLUDE_RUNTIME="${INCLUDE_RUNTIME:-0}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
SKILL_VERSION="${SKILL_VERSION:-1.2.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_JSON="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-sarif.sh"

if [ ! -f "$EMIT_JSON" ]; then
    echo "build-findings: shared JSON emitter not found at $EMIT_JSON" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATIC_OUT="${TMP_DIR}/static.json"
RUNTIME_OUT="${TMP_DIR}/runtime.json"
STATIC_ERR="${TMP_DIR}/static.err"
RUNTIME_ERR="${TMP_DIR}/runtime.err"

run_scanner() {
    local name="$1" out="$2" err="$3"; shift 3
    if ! bash "$@" > "$out" 2> "$err"; then
        echo "$name: scanner returned non-zero exit" >> "$err"
        echo "[]" > "$out"
        return 1
    fi
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$out" 2>/dev/null; then
        echo "$name: produced invalid JSON" >> "$err"
        echo "[]" > "$out"
        return 1
    fi
    return 0
}

# Scan the module subtree when scoped to a single module; only widen to SCAN_ROOT for a
# site-wide audit. Scanning all of SCAN_ROOT for a single-module run would both slow the
# scan and attribute other modules' findings to this target.
if [ "$SCOPE" = "site" ]; then
    STATIC_SCAN_TARGET="$SCAN_ROOT"
else
    STATIC_SCAN_TARGET="$TARGET_PATH"
fi
run_scanner static-perf "$STATIC_OUT" "$STATIC_ERR" "${SCRIPT_DIR}/static-perf.sh" "$STATIC_SCAN_TARGET" || true

if [ "$INCLUDE_RUNTIME" = "1" ]; then
    if [ -f "${SCRIPT_DIR}/runtime-checks.sh" ]; then
        run_scanner runtime-checks "$RUNTIME_OUT" "$RUNTIME_ERR" "${SCRIPT_DIR}/runtime-checks.sh" || true
        # runtime-checks.sh emits a findings array. Distinguish "ran but produced no
        # findings" (e.g. every probe tool absent) from "found problems" so the report
        # never conflates "scanner didn't run" with "scanner found nothing".
        if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,list) and d else 1)" "$RUNTIME_OUT" 2>/dev/null; then
            :
        else
            echo "runtime-checks: INCLUDE_RUNTIME=1 but no runtime findings were produced (probe tools likely unavailable — this is not the same as a clean result)" >> "$RUNTIME_ERR"
        fi
    else
        echo "[]" > "$RUNTIME_OUT"
        echo "runtime-checks: INCLUDE_RUNTIME=1 but ${SCRIPT_DIR}/runtime-checks.sh not found" >> "$RUNTIME_ERR"
    fi
else
    echo "[]" > "$RUNTIME_OUT"
fi

# Build scanner_errors JSON.
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [
    ('static-perf',    '${STATIC_ERR}'),
    ('runtime-checks', '${RUNTIME_ERR}'),
]
errors = []
for name, path in scanners:
    if os.path.exists(path) and os.path.getsize(path) > 0:
        text = open(path, encoding='utf-8', errors='replace').read().strip()
        if text:
            errors.append({'scanner': name, 'stderr': text})
print(json.dumps(errors, indent=2))
PY

FINDINGS_FILE="${TMP_DIR}/findings.json"
python3 - "$STATIC_OUT" "$RUNTIME_OUT" > "$FINDINGS_FILE" <<'PY'
import json
import sys

merged = []
for path in sys.argv[1:]:
    try:
        with open(path) as fh:
            data = json.load(fh)
        if isinstance(data, list):
            merged.extend(data)
    except Exception:
        continue

print(json.dumps(merged, indent=2))
PY

DATE="$(date -u +%Y-%m-%d)"
export FINDINGS_FILE
export TARGET_MODULE TARGET_PATH SCOPE
export SKILL_NAME="magento2-performance-audit"
export SKILL_VERSION
export OUTPUT_KIND="performance"
if [ "$SCOPE" = "module" ]; then
    export OUTPUT_BASENAME="${TARGET_MODULE}-perf-${DATE}"
else
    export OUTPUT_BASENAME="perf-${SCOPE}-${DATE}"
fi
export OUTPUT_DIR
export SKILL_VERSIONS_JSON="[\"magento2-performance-audit@${SKILL_VERSION}\",\"magento2-context@1.9.0\"]"

bash "$EMIT_JSON" > /dev/null

OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}.json"
if [ -f "$OUTPUT_FILE" ] && [ -f "$SCANNER_ERRORS_FILE" ]; then
    python3 - "$OUTPUT_FILE" "$SCANNER_ERRORS_FILE" <<'PY'
import json, sys
doc_path, err_path = sys.argv[1], sys.argv[2]
with open(doc_path) as fh:
    doc = json.load(fh)
with open(err_path) as fh:
    errors = json.load(fh)
doc['scanner_errors'] = errors
with open(doc_path, 'w') as fh:
    json.dump(doc, fh, indent=2)
PY
fi

# Emit SARIF alongside JSON.
SARIF_OUTPUT="${OUTPUT_DIR}/${OUTPUT_BASENAME}.sarif"
if [ -f "$EMIT_SARIF" ] && [ -f "$OUTPUT_FILE" ]; then
    if ! bash "$EMIT_SARIF" "$OUTPUT_FILE" > "$SARIF_OUTPUT" 2> "${TMP_DIR}/sarif.err"; then
        python3 - "$OUTPUT_FILE" "${TMP_DIR}/sarif.err" <<'PY'
import json, os, sys
doc_path, err_path = sys.argv[1], sys.argv[2]
try:
    with open(doc_path) as fh:
        doc = json.load(fh)
    err = open(err_path).read().strip() if os.path.exists(err_path) else ""
    doc.setdefault("scanner_errors", []).append({
        "scanner": "emit-sarif",
        "stderr": err or "emit-sarif.sh failed with non-zero exit",
    })
    with open(doc_path, "w") as fh:
        json.dump(doc, fh, indent=2)
except Exception:
    pass
PY
    fi
fi

cat "$OUTPUT_FILE"
