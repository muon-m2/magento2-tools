#!/usr/bin/env bash
# build-findings.sh — run the Breeze static compatibility scanner and emit one findings
# document (skill-labelled as breeze-compat, output kind "compatibility").
# Thin wrapper over the shared engine context/scripts/findings-lib.sh.
#
# Inputs (env vars):
#   TARGET_MODULE   e.g. "Acme_Foo" (required)
#   TARGET_PATH     e.g. "app/code/Acme/Foo" (required)
#   SCOPE           "module" (default) | "site"
#   SCAN_ROOT       default: app/code or src/app/code
#   DOCS_ROOT       default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR      default: {DOCS_ROOT}/breeze-compat
#   SKILL_VERSION   default: 1.1.1
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-breeze-compat-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/breeze-compat-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/breeze-compat}"
SKILL_VERSION="${SKILL_VERSION:-1.1.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init

if [ "$SCOPE" = "site" ]; then
    STATIC_SCAN_TARGET="$SCAN_ROOT"
else
    STATIC_SCAN_TARGET="$TARGET_PATH"
fi
findings_scan static-scan "${SCRIPT_DIR}/static-scan.sh" "$STATIC_SCAN_TARGET" || true

SKILL_NAME="breeze-compat"
OUTPUT_KIND="compatibility"
BASENAME_KIND="breeze-compat"
findings_emit
