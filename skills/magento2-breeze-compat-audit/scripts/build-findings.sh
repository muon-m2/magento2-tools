#!/usr/bin/env bash
# build-findings.sh — run the Breeze static compatibility scanner and emit one findings
# document via the shared emit-json.sh / emit-sarif.sh pipeline (skill-labelled as
# magento2-breeze-compat-audit, output kind "compatibility"). Also emits SARIF.
#
# Structurally identical to magento2-performance-audit/scripts/build-findings.sh (single
# scanner, no runtime pass) so the audit skills share one mental model.
#
# Inputs (env vars):
#   TARGET_MODULE   e.g. "Acme_Foo" (required)
#   TARGET_PATH     e.g. "app/code/Acme/Foo" (required)
#   SCOPE           "module" (default) | "site"
#   SCAN_ROOT       default: app/code or src/app/code
#   DOCS_ROOT       default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR      default: {DOCS_ROOT}/breeze-compat
#   SKILL_VERSION   default: 1.1.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-breeze-compat-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/breeze-compat-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/breeze-compat}"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATIC_OUT="${TMP_DIR}/static.json"
STATIC_ERR="${TMP_DIR}/static.err"

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

if [ "$SCOPE" = "site" ]; then
    STATIC_SCAN_TARGET="$SCAN_ROOT"
else
    STATIC_SCAN_TARGET="$TARGET_PATH"
fi
run_scanner static-scan "$STATIC_OUT" "$STATIC_ERR" "${SCRIPT_DIR}/static-scan.sh" "$STATIC_SCAN_TARGET" || true

# Build scanner_errors JSON.
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [('static-scan', '${STATIC_ERR}')]
errors = []
for name, path in scanners:
    if os.path.exists(path) and os.path.getsize(path) > 0:
        text = open(path, encoding='utf-8', errors='replace').read().strip()
        if text:
            errors.append({'scanner': name, 'stderr': text})
print(json.dumps(errors, indent=2))
PY

FINDINGS_FILE="${TMP_DIR}/findings.json"
cp "$STATIC_OUT" "$FINDINGS_FILE"

# Emit via the shared hub pipeline (JSON + SARIF).
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-breeze-compat-audit"
export SKILL_VERSION
export OUTPUT_KIND="compatibility"
export SKILL_VERSIONS_JSON="[\"magento2-breeze-compat-audit@${SKILL_VERSION}\",\"magento2-context@1.9.0\"]"

BASENAME_KIND="breeze-compat" bash "$EMIT_FINDINGS"
