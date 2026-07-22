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
#   SCAN_ROOT           default: src/app/code  (cross-module scan)
#   SECRET_ROOT         default: SCAN_ROOT without /code, i.e. the app/ tree (secret scan,
#                       so app/etc/env.php is covered)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See magento2-context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/audits
#   SKILL_VERSION       default: 1.6.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-security-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/security-{SCOPE}-{YYYY-MM-DD}.json (site/vendor scope) to stdout AND file.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
COMPOSER_LOCK="${COMPOSER_LOCK:-$([[ -f composer.lock ]] && echo composer.lock || echo src/composer.lock)}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
# Secret scanning needs to reach app/etc/env.php (the crypt key), which sits OUTSIDE app/code.
# Derive the `app/` tree from SCAN_ROOT for secret-scan only; cross-module keeps app/code so its
# vendor/module discovery is unaffected.
SECRET_ROOT="${SECRET_ROOT:-${SCAN_ROOT%/code}}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
SKILL_VERSION="${SKILL_VERSION:-1.6.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
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
run_scanner secret "$SECRET_OUT" "$SECRET_ERR" "${SCRIPT_DIR}/secret-scan.sh" "$SECRET_ROOT" || true
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

# Emit via the shared hub pipeline (JSON + SARIF). The magento_core_cve_status block is
# injected between JSON and SARIF by the POST_JSON_HOOK so it lands in JSON only, matching
# the prior behaviour. scanner_errors is carried by emit-json.sh via SCANNER_ERRORS_FILE.
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-security-audit"
export SKILL_VERSION
export OUTPUT_KIND="security"
export SKILL_VERSIONS_JSON="[\"magento2-security-audit@${SKILL_VERSION}\",\"magento2-context@1.11.0\"]"

BASENAME_KIND="security" POST_JSON_HOOK="${SCRIPT_DIR}/inject-cve-status.sh" bash "$EMIT_FINDINGS"
