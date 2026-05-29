#!/usr/bin/env bash
# build-findings.sh — aggregate security scanner outputs into one findings JSON, then
# emit the unified document via the shared emit-json.sh pipeline (skill-labelled as
# magento2-security-audit, output kind "security").
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderS3Export" or "site"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderS3Export" or "."
#   SCOPE               "module" | "site" | "vendor"  (default: module)
#   COMPOSER_LOCK       default: src/composer.lock
#   SCAN_ROOT           default: src/app/code  (for secret/cross-module scans)
#   OUTPUT_DIR          default: .docs/audits
#   SKILL_VERSION       default: 1.1.0
#
# Output:
#   Writes {OUTPUT_DIR}/security-{SCOPE}-{YYYY-MM-DD}.json to stdout AND saves to file.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
COMPOSER_LOCK="${COMPOSER_LOCK:-$([[ -f composer.lock ]] && echo composer.lock || echo src/composer.lock)}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
OUTPUT_DIR="${OUTPUT_DIR:-.docs/audits}"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_JSON="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-sarif.sh"

if [ ! -f "$EMIT_JSON" ]; then
    echo "build-findings: shared JSON emitter not found at $EMIT_JSON" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CVE_OUT="${TMP_DIR}/cve.json"
SECRET_OUT="${TMP_DIR}/secret.json"
CROSS_OUT="${TMP_DIR}/cross.json"
CVE_ERR="${TMP_DIR}/cve.err"
SECRET_ERR="${TMP_DIR}/secret.err"
CROSS_ERR="${TMP_DIR}/cross.err"

# Run each scanner. stderr is captured per-scanner so a silent crash is visible in
# the final report under `scanner_errors`. Exit-non-zero AND empty/invalid JSON both
# fall back to [] but are recorded.
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

run_scanner cve "$CVE_OUT" "$CVE_ERR" "${SCRIPT_DIR}/cve-scan.sh" "$COMPOSER_LOCK" || true
run_scanner secret "$SECRET_OUT" "$SECRET_ERR" "${SCRIPT_DIR}/secret-scan.sh" "$SCAN_ROOT" || true
run_scanner cross-module "$CROSS_OUT" "$CROSS_ERR" "${SCRIPT_DIR}/cross-module-scan.sh" "$SCAN_ROOT" || true

# Build scanner_errors JSON: one entry per scanner that emitted on stderr or crashed.
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
python3 - <<PY > "$SCANNER_ERRORS_FILE"
import json
import os

scanners = [
    ('cve-scan',         '${CVE_ERR}'),
    ('secret-scan',      '${SECRET_ERR}'),
    ('cross-module-scan','${CROSS_ERR}'),
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
python3 - "$CVE_OUT" "$SECRET_OUT" "$CROSS_OUT" > "$FINDINGS_FILE" <<'PY'
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
export SKILL_NAME="magento2-security-audit"
export SKILL_VERSION
export OUTPUT_KIND="security"
export OUTPUT_BASENAME="security-${SCOPE}-${DATE}"
export OUTPUT_DIR
export SKILL_VERSIONS_JSON="[\"magento2-security-audit@${SKILL_VERSION}\",\"magento2-context@1.3.0\"]"

bash "$EMIT_JSON" > /dev/null

# Derive Magento-core CVE coverage status so consumers can act on the absence of live
# data without inferring it from missing findings. Read the data file's status marker.
CVE_DATA_FILE="${SCRIPT_DIR}/../references/magento-cve-data.yaml"
MAGENTO_CORE_CVE_STATUS="missing"
MAGENTO_CORE_CVE_REFRESHED=""
if [ -f "$CVE_DATA_FILE" ]; then
    MAGENTO_CORE_CVE_STATUS="$(grep -E '^status:' "$CVE_DATA_FILE" | head -1 | sed -E 's/^status:\s*//; s/\s+$//' || true)"
    MAGENTO_CORE_CVE_REFRESHED="$(grep -E '^last_refreshed:' "$CVE_DATA_FILE" | head -1 | sed -E 's/^last_refreshed:\s*//; s/\s+$//' || true)"
fi
[ -z "$MAGENTO_CORE_CVE_STATUS" ] && MAGENTO_CORE_CVE_STATUS="missing"

# Inject scanner_errors and magento_core_cve_status into the emitted document so silent
# scanner crashes and inert CVE coverage are visible to consumers.
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}.json"
if [ -f "$OUTPUT_FILE" ] && [ -f "$SCANNER_ERRORS_FILE" ]; then
    MAGENTO_CORE_CVE_STATUS="$MAGENTO_CORE_CVE_STATUS" \
    MAGENTO_CORE_CVE_REFRESHED="$MAGENTO_CORE_CVE_REFRESHED" \
    python3 - "$OUTPUT_FILE" "$SCANNER_ERRORS_FILE" <<'PY'
import json, os, sys
doc_path, err_path = sys.argv[1], sys.argv[2]
with open(doc_path) as fh:
    doc = json.load(fh)
with open(err_path) as fh:
    errors = json.load(fh)
doc['scanner_errors'] = errors

status = os.environ.get('MAGENTO_CORE_CVE_STATUS', 'missing').strip() or 'missing'
refreshed = os.environ.get('MAGENTO_CORE_CVE_REFRESHED', '').strip()
note_by_status = {
    'live':          'Live Magento CVE data loaded; matching is authoritative.',
    'illustrative':  'Magento CVE source is illustrative — matches are reported as candidates, not confirmed advisories.',
    'missing':       'Magento CVE data file not found; Magento-core CVE matching disabled.',
}
note = note_by_status.get(status, f"Unknown Magento CVE data status '{status}'.")
doc['magento_core_cve_status'] = {
    'status': status,
    'last_refreshed': refreshed or None,
    'note': note,
    'source': 'magento2-security-audit/references/magento-cve-data.yaml',
}

with open(doc_path, 'w') as fh:
    json.dump(doc, fh, indent=2)
PY
fi

# Emit SARIF alongside JSON so the SKILL.md output triple (Markdown + JSON + SARIF) is
# actually produced by a single invocation rather than requiring callers to remember
# the SARIF step. Skip silently when emit-sarif.sh is unavailable; record the failure
# under scanner_errors so consumers know.
SARIF_OUTPUT="${OUTPUT_DIR}/${OUTPUT_BASENAME}.sarif"
if [ -f "$EMIT_SARIF" ] && [ -f "$OUTPUT_FILE" ]; then
    if ! bash "$EMIT_SARIF" "$OUTPUT_FILE" > "$SARIF_OUTPUT" 2> "${TMP_DIR}/sarif.err"; then
        python3 - "$OUTPUT_FILE" "${TMP_DIR}/sarif.err" <<'PY'
import json, sys
doc_path, err_path = sys.argv[1], sys.argv[2]
try:
    with open(doc_path) as fh:
        doc = json.load(fh)
    err = open(err_path).read().strip() if __import__("os").path.exists(err_path) else ""
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

# Echo the final JSON document for callers that read stdout.
cat "$OUTPUT_FILE"
