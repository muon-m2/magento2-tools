#!/usr/bin/env bash
# build-findings.sh — aggregate accessibility scanner outputs into one findings document
# (skill-labelled as a11y-audit, output kind "accessibility"). Thin
# wrapper over the shared engine context/scripts/findings-lib.sh.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_Storefront" or "theme"
#   TARGET_PATH         e.g. "src/app/code/Acme/Storefront" or "app/design/frontend/Acme/storefront"
#   SCOPE               "module" | "theme" | "site"  (default: module)
#   THEME               Active frontend theme (default: "")
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR          default: {DOCS_ROOT}/accessibility
#   SKILL_VERSION       default: 1.2.0
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-a11y-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/a11y-{SCOPE}-{YYYY-MM-DD}.json (theme/site scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
THEME="${THEME:-}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/accessibility}"
SKILL_VERSION="${SKILL_VERSION:-1.2.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init

TARGET_PATH="$TARGET_PATH" TARGET_MODULE="$TARGET_MODULE" THEME="$THEME" \
    findings_scan scan-templates "${SCRIPT_DIR}/scan-templates.sh" || true

SKILL_NAME="a11y-audit"
OUTPUT_KIND="accessibility"
BASENAME_KIND="a11y"
findings_emit
