#!/usr/bin/env bash
# build-findings.sh — aggregate performance scanner output into one findings document
# (skill-labelled as perf-audit, output kind "performance"). Thin wrapper
# over the shared engine context/scripts/findings-lib.sh.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderS3Export" or "site"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderS3Export" or "."
#   SCOPE               "module" | "site"  (default: module)
#   SCAN_ROOT           default: src/app/code
#   INCLUDE_RUNTIME     "1" to include runtime-checks.sh output (default: off)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR          default: {DOCS_ROOT}/audits
#   SKILL_VERSION       default: 1.3.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-perf-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/perf-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes the JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
INCLUDE_RUNTIME="${INCLUDE_RUNTIME:-0}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
SKILL_VERSION="${SKILL_VERSION:-1.3.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init

# Scan the module subtree when scoped to a single module; only widen to SCAN_ROOT for a
# site-wide audit. Scanning all of SCAN_ROOT for a single-module run would both slow the
# scan and attribute other modules' findings to this target.
if [ "$SCOPE" = "site" ]; then
    STATIC_SCAN_TARGET="$SCAN_ROOT"
else
    STATIC_SCAN_TARGET="$TARGET_PATH"
fi
findings_scan static-perf "${SCRIPT_DIR}/static-perf.sh" "$STATIC_SCAN_TARGET" || true

if [ "$INCLUDE_RUNTIME" = "1" ]; then
    if [ -f "${SCRIPT_DIR}/runtime-checks.sh" ]; then
        findings_scan runtime-checks "${SCRIPT_DIR}/runtime-checks.sh" || true
        # Distinguish "ran but produced no findings" (e.g. every probe tool absent) from
        # "found problems" so the report never conflates "scanner didn't run" with
        # "scanner found nothing".
        if ! python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,list) and d else 1)" "${TMP_DIR}/runtime-checks.json" 2>/dev/null; then
            echo "runtime-checks: INCLUDE_RUNTIME=1 but no runtime findings were produced (probe tools likely unavailable — this is not the same as a clean result)" >> "${TMP_DIR}/runtime-checks.err"
        fi
    else
        echo "[]" > "${TMP_DIR}/runtime-checks.json"
        echo "runtime-checks: INCLUDE_RUNTIME=1 but ${SCRIPT_DIR}/runtime-checks.sh not found" > "${TMP_DIR}/runtime-checks.err"
        findings_register runtime-checks "${TMP_DIR}/runtime-checks.json" "${TMP_DIR}/runtime-checks.err"
    fi
fi

SKILL_NAME="perf-audit"
OUTPUT_KIND="performance"
BASENAME_KIND="perf"
findings_emit
