#!/usr/bin/env bash
# build-findings.sh — aggregate static-analysis scanner outputs into one findings JSON,
# then emit the unified document via the shared emit-json.sh pipeline (skill-labelled as
# magento2-static-analysis, output kind "quality"). Also emits SARIF.
#
# Structurally identical to magento2-security-audit/scripts/build-findings.sh so all
# audit skills share one mental model.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderS3Export" or "site"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderS3Export" or "."
#   SCOPE               "module" | "site" | "diff"  (default: module)
#   SCAN_ROOT           default: src/app/code
#   RUNNER              Runner prefix (default: "")
#   PHPCS               phpcs binary path (default: auto-resolved)
#   PHPSTAN             phpstan binary path (default: auto-resolved)
#   PHPMD               phpmd binary path (default: auto-resolved)
#   RECTOR              rector binary path (default: auto-resolved)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See magento2-context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/quality
#   SKILL_VERSION       default: 1.1.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-quality-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/quality-{SCOPE}-{YYYY-MM-DD}.json (site/diff scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$( [ -d app/code ] && echo app/code || echo src/app/code )}"
RUNNER="${RUNNER:-}"
PHPCS="${PHPCS:-}"
PHPSTAN="${PHPSTAN:-}"
PHPMD="${PHPMD:-}"
RECTOR="${RECTOR:-}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/quality}"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ANALYSIS_OUT="${TMP_DIR}/analysis.json"
ANALYSIS_ERR="${TMP_DIR}/analysis.err"

# run-analysis.sh writes the findings array to a tmp file and prints its path.
# We capture that path and read the file.
ANALYSIS_FINDINGS_PATH=""
FINDINGS_FILE_OVERRIDE="${TMP_DIR}/analysis_findings.json"

RUNNER="$RUNNER" \
PHPCS="$PHPCS" \
PHPSTAN="$PHPSTAN" \
PHPMD="$PHPMD" \
RECTOR="$RECTOR" \
TARGET_PATH="$TARGET_PATH" \
SCOPE="$SCOPE" \
FINDINGS_FILE="$FINDINGS_FILE_OVERRIDE" \
    bash "${SCRIPT_DIR}/run-analysis.sh" > "${TMP_DIR}/analysis_path.txt" 2> "$ANALYSIS_ERR" || true

if [ -f "$FINDINGS_FILE_OVERRIDE" ]; then
    cp "$FINDINGS_FILE_OVERRIDE" "$ANALYSIS_OUT"
else
    echo "[]" > "$ANALYSIS_OUT"
    echo "run-analysis: findings file not produced" >> "$ANALYSIS_ERR"
fi

# Validate the JSON output.
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$ANALYSIS_OUT" 2>/dev/null; then
    echo "run-analysis: produced invalid JSON" >> "$ANALYSIS_ERR"
    echo "[]" > "$ANALYSIS_OUT"
fi

# Build scanner_errors JSON.
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [
    ('run-analysis', '${ANALYSIS_ERR}'),
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
python3 - "$ANALYSIS_OUT" > "$FINDINGS_FILE" <<'PY'
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

# Emit via the shared hub pipeline (JSON + SARIF).
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-static-analysis"
export SKILL_VERSION
export OUTPUT_KIND="quality"
export SKILL_VERSIONS_JSON="[\"magento2-static-analysis@${SKILL_VERSION}\",\"magento2-context@1.9.0\"]"

BASENAME_KIND="quality" bash "$EMIT_FINDINGS"
