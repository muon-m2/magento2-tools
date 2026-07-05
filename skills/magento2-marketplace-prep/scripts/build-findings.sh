#!/usr/bin/env bash
# build-findings.sh — aggregate marketplace readiness checker outputs into one findings JSON,
# then emit the unified document via the shared emit-json.sh pipeline (skill-labelled as
# magento2-marketplace-prep, output kind "marketplace"). Also emits SARIF.
#
# Structurally identical to magento2-security-audit/scripts/build-findings.sh so all
# audit skills share one mental model.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderExport"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderExport"
#   SCOPE               "module" | "site"  (default: module)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See magento2-context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/marketplace
#   SKILL_VERSION       default: 1.1.0
#   EQP_FINDINGS_FILE   optional: path to a JSON array of EQP static findings produced by
#                       magento2-security-audit's EQP pass (SKILL.md Phase 2.2). When set and
#                       readable, those findings are merged into the combined findings list.
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-readiness-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/readiness-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/marketplace}"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"
EQP_FINDINGS_FILE="${EQP_FINDINGS_FILE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

READINESS_OUT="${TMP_DIR}/readiness.json"
READINESS_ERR="${TMP_DIR}/readiness.err"

# ---------------------------------------------------------------------------
# Run the marketplace-specific readiness checker.
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

run_scanner check-readiness "$READINESS_OUT" "$READINESS_ERR" \
    "${SCRIPT_DIR}/check-readiness.sh" || true

# ---------------------------------------------------------------------------
# Build scanner_errors JSON.
# ---------------------------------------------------------------------------
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [
    ('check-readiness', '${READINESS_ERR}'),
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
# Merge all findings into one array. The marketplace-specific check-readiness
# output is always included; the delegated magento2-security-audit EQP findings
# (SKILL.md Phase 2.2) are merged in when EQP_FINDINGS_FILE is provided.
# ---------------------------------------------------------------------------
MERGE_INPUTS=("$READINESS_OUT")
if [ -n "$EQP_FINDINGS_FILE" ] && [ -f "$EQP_FINDINGS_FILE" ]; then
    MERGE_INPUTS+=("$EQP_FINDINGS_FILE")
fi

FINDINGS_FILE="${TMP_DIR}/findings.json"
python3 - "${MERGE_INPUTS[@]}" > "$FINDINGS_FILE" <<'PY'
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
# Emit via the shared hub pipeline (JSON + SARIF). The readiness score/verdict is
# injected between JSON and SARIF by the POST_JSON_HOOK. scanner_errors is carried by
# emit-json.sh via SCANNER_ERRORS_FILE.
# ---------------------------------------------------------------------------
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-marketplace-prep"
export SKILL_VERSION
export OUTPUT_KIND="marketplace"
export SKILL_VERSIONS_JSON="[\"magento2-marketplace-prep@${SKILL_VERSION}\",\"magento2-context@1.9.0\"]"

BASENAME_KIND="readiness" POST_JSON_HOOK="${SCRIPT_DIR}/compute-readiness-score.sh" bash "$EMIT_FINDINGS"
