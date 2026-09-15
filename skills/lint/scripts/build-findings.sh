#!/usr/bin/env bash
# build-findings.sh — aggregate static-analysis scanner outputs into one findings
# document (skill-labelled as lint, output kind "quality"). Thin
# wrapper over the shared engine context/scripts/findings-lib.sh.
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
#   PHPSTAN_CONFIG      phpstan config to pass as -c (default: auto-discovered, nearest first —
#                       {TARGET_PATH}/phpstan.neon, then a phpstan-devpath.neon or phpstan.neon
#                       beside the target's parent dir, then the Magento root, then the cwd).
#                       WITHOUT a config phpstan loads no bootstrap and no autoloader, so every
#                       framework class reads as unknown and the pass emits confident false
#                       positives. When none is found the run is still made, but a warning lands in
#                       scanner_errors saying so.
#   RECTOR_FORCE        "1" runs rector even on a pairing known to be broken. Rector 1.x on PHP
#                       >= 8.5 floods stderr with setAccessible deprecations and never emits
#                       parseable JSON, so it is skipped by default with an explanatory
#                       scanner_errors entry. Rector ^2.5 runs clean on 8.5 and is NOT skipped —
#                       note it requires phpstan ^2.2, so adopting it implies the PHPStan 2.x
#                       migration.
#   PHPSTAN_MEMORY_LIMIT
#                       Value for phpstan's --memory-limit (default: 2G). php.ini's default
#                       (commonly 128M) crashes phpstan on a Magento codebase and returns an
#                       apparently-clean result. Forwarded to run-analysis.sh.
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR          default: {DOCS_ROOT}/quality
#   SKILL_VERSION       default: 1.4.1
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-quality-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/quality-{SCOPE}-{YYYY-MM-DD}.json (site/diff scope) + .sarif. Stdout echoes JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
SCAN_ROOT="${SCAN_ROOT:-$( [ -d app/code ] && echo app/code || echo src/app/code )}"
RUNNER="${RUNNER:-}"
PHPCS="${PHPCS:-}"
PHPSTAN="${PHPSTAN:-}"
PHPMD="${PHPMD:-}"
RECTOR="${RECTOR:-}"
PHPSTAN_CONFIG="${PHPSTAN_CONFIG:-}"
RECTOR_FORCE="${RECTOR_FORCE:-0}"
PHPSTAN_MEMORY_LIMIT="${PHPSTAN_MEMORY_LIMIT:-2G}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/quality}"
SKILL_VERSION="${SKILL_VERSION:-1.4.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init

# run-analysis.sh has a non-standard contract (it writes the findings array to
# FINDINGS_FILE itself), so run it directly and register its output afterwards.
ANALYSIS_OUT="${TMP_DIR}/run-analysis.json"
ANALYSIS_ERR="${TMP_DIR}/run-analysis.err"
# Per-scanner executed / unavailable / skipped / degraded, which emit-json.sh publishes as the
# document's `tools` map. Nothing set it before, so every quality document carried `tools: {}` and
# could not say which scanners had actually looked at the code.
TOOLS_FILE="${TMP_DIR}/tools.json"
export TOOLS_FILE

RUNNER="$RUNNER" \
PHPCS="$PHPCS" \
PHPSTAN="$PHPSTAN" \
PHPMD="$PHPMD" \
RECTOR="$RECTOR" \
PHPSTAN_CONFIG="$PHPSTAN_CONFIG" \
RECTOR_FORCE="$RECTOR_FORCE" \
PHPSTAN_MEMORY_LIMIT="$PHPSTAN_MEMORY_LIMIT" \
TARGET_PATH="$TARGET_PATH" \
SCOPE="$SCOPE" \
FINDINGS_FILE="$ANALYSIS_OUT" \
    bash "${SCRIPT_DIR}/run-analysis.sh" > "${TMP_DIR}/analysis_path.txt" 2> "$ANALYSIS_ERR" || true

findings_register run-analysis "$ANALYSIS_OUT" "$ANALYSIS_ERR"

SKILL_NAME="lint"
OUTPUT_KIND="quality"
BASENAME_KIND="quality"
findings_emit
