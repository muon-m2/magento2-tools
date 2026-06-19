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
#   OUTPUT_DIR          default: .docs/quality
#   SKILL_VERSION       default: 1.0.0
#
# Output:
#   Writes {OUTPUT_DIR}/quality-{SCOPE}-{YYYY-MM-DD}.json + .sarif. Stdout echoes the JSON.

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
OUTPUT_DIR="${OUTPUT_DIR:-.docs/quality}"
SKILL_VERSION="${SKILL_VERSION:-1.0.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_JSON="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-sarif.sh"

if [ ! -f "$EMIT_JSON" ]; then
    echo "build-findings: shared JSON emitter not found at $EMIT_JSON" >&2
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

DATE="$(date -u +%Y-%m-%d)"
export FINDINGS_FILE
export TARGET_MODULE TARGET_PATH SCOPE
export SKILL_NAME="magento2-static-analysis"
export SKILL_VERSION
export OUTPUT_KIND="quality"
export OUTPUT_BASENAME="quality-${SCOPE}-${DATE}"
export OUTPUT_DIR
export SKILL_VERSIONS_JSON="[\"magento2-static-analysis@${SKILL_VERSION}\",\"magento2-context@1.6.1\"]"

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
