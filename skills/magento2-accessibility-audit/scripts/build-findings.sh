#!/usr/bin/env bash
# build-findings.sh — aggregate accessibility scanner outputs into one findings JSON,
# then emit the unified document via the shared emit-json.sh pipeline (skill-labelled as
# magento2-accessibility-audit, output kind "accessibility"). Also emits SARIF.
#
# Structurally identical to magento2-marketplace-prep/scripts/build-findings.sh so all
# audit skills share one mental model.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_Storefront" or "theme"
#   TARGET_PATH         e.g. "src/app/code/Acme/Storefront" or "app/design/frontend/Acme/storefront"
#   SCOPE               "module" | "theme" | "site"  (default: module)
#   THEME               Active frontend theme (default: "")
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See magento2-context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/accessibility
#   SKILL_VERSION       default: 1.1.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-a11y-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/a11y-{SCOPE}-{YYYY-MM-DD}.json (theme/site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
THEME="${THEME:-}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/accessibility}"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SCAN_OUT="${TMP_DIR}/scan.json"
SCAN_ERR="${TMP_DIR}/scan.err"

# ---------------------------------------------------------------------------
# Run the accessibility static scanner.
# ---------------------------------------------------------------------------
run_scanner() {
    local name="$1" out="$2" err="$3"; shift 3
    if ! bash "$@" > "$out" 2> "$err"; then
        echo "$name: scanner returned non-zero exit" >> "$err"
        echo "[]" > "$out"
        return 1
    fi
    # Validate JSON; on parse failure, replace with []
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$out" 2>/dev/null; then
        echo "$name: produced invalid JSON" >> "$err"
        echo "[]" > "$out"
        return 1
    fi
    return 0
}

TARGET_PATH="$TARGET_PATH" \
TARGET_MODULE="$TARGET_MODULE" \
THEME="$THEME" \
run_scanner scan-templates "$SCAN_OUT" "$SCAN_ERR" \
    "${SCRIPT_DIR}/scan-templates.sh" || true

# ---------------------------------------------------------------------------
# Build scanner_errors JSON.
# ---------------------------------------------------------------------------
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [
    ('scan-templates', '${SCAN_ERR}'),
]
errors = []
for name, path in scanners:
    if os.path.exists(path) and os.path.getsize(path) > 0:
        text = open(path, encoding='utf-8', errors='replace').read().strip()
        if text:
            errors.append({'scanner': name, 'stderr': text})
print(json.dumps(errors, indent=2))
PY

# ---------------------------------------------------------------------------
# Merge all findings into one array.
# ---------------------------------------------------------------------------
FINDINGS_FILE="${TMP_DIR}/findings.json"
python3 - "$SCAN_OUT" > "$FINDINGS_FILE" <<'PY'
import json
import sys

merged = []
for path in sys.argv[1:]:
    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        if isinstance(data, list):
            merged.extend(data)
    except Exception:
        continue

print(json.dumps(merged, indent=2))
PY

# ---------------------------------------------------------------------------
# Emit via the shared hub pipeline (JSON + SARIF).
# ---------------------------------------------------------------------------
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-accessibility-audit"
export SKILL_VERSION
export OUTPUT_KIND="accessibility"
export SKILL_VERSIONS_JSON="[\"magento2-accessibility-audit@${SKILL_VERSION}\",\"magento2-context@1.10.0\"]"

BASENAME_KIND="a11y" bash "$EMIT_FINDINGS"
