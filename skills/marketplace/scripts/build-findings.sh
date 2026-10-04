#!/usr/bin/env bash
# build-findings.sh — aggregate marketplace readiness checker outputs into one findings
# document (skill-labelled as marketplace, output kind "marketplace").
# Thin wrapper over the shared engine context/scripts/findings-lib.sh.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderExport"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderExport"
#   SCOPE               "module" | "site"  (default: module)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR          default: {DOCS_ROOT}/marketplace
#   SKILL_VERSION       default: 1.2.0
#   EQP_FINDINGS_FILE   optional: path to a JSON array of EQP static findings produced by
#                       security's EQP pass (SKILL.md Phase 2.2). When set and
#                       readable, those findings are merged into the combined findings list.
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-readiness-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/readiness-{SCOPE}-{YYYY-MM-DD}.json (site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/marketplace}"
SKILL_VERSION="${SKILL_VERSION:-1.2.0}"
EQP_FINDINGS_FILE="${EQP_FINDINGS_FILE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init
findings_scan check-readiness "${SCRIPT_DIR}/check-readiness.sh" || true

# The delegated security EQP findings (SKILL.md Phase 2.2) are merged in
# when EQP_FINDINGS_FILE is provided. The readiness score/verdict is injected between
# JSON and SARIF by the POST_JSON_HOOK.
EXTRA=()
if [ -n "$EQP_FINDINGS_FILE" ] && [ -f "$EQP_FINDINGS_FILE" ]; then
    EXTRA+=("$EQP_FINDINGS_FILE")
fi

SKILL_NAME="marketplace"
OUTPUT_KIND="marketplace"
BASENAME_KIND="readiness"
POST_JSON_HOOK="${SCRIPT_DIR}/compute-readiness-score.sh" findings_emit ${EXTRA[@]+"${EXTRA[@]}"}
