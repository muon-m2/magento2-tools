#!/usr/bin/env bash
# emit-report.sh — emit the module-upgrade findings document (JSON + SARIF) via the shared
# magento2-context hub emitter.
#
# The upgrade report's Markdown is authored by the skill in-conversation; this script produces
# the schema-conforming JSON + SARIF siblings so upgrade findings (deprecations, BC-breaks)
# feed CI / GitHub Code Scanning like every other findings-emitting skill. Replaces the prior
# inline JSON-only emitter, which produced no SARIF.
#
# Inputs (env vars):
#   FINDINGS_FILE     JSON array of upgrade findings assembled by the skill (required).
#                     Each finding's category ∈ deprecation | bc_break | magento_compat | php_compat.
#   TARGET_MODULE     e.g. "Acme_Foo" (required).
#   TARGET_PATH       e.g. "src/app/code/Acme/Foo" (required).
#   OUTPUT_BASENAME   e.g. "Acme_Foo-2.4.5-to-2.4.7-2026-07-04" (required — the upgrade report
#                     uses a version-range basename, not the resolve-basename.sh scheme).
#   DOCS_ROOT         default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR        default: {DOCS_ROOT}/upgrades.
#   SKILL_VERSION     default: 1.2.0.
#
# Output:
#   Writes {OUTPUT_DIR}/{OUTPUT_BASENAME}.json and .sarif; echoes the JSON to stdout.

set -uo pipefail

: "${FINDINGS_FILE:?FINDINGS_FILE is required}"
: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"
: "${OUTPUT_BASENAME:?OUTPUT_BASENAME is required}"

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/upgrades}"
SKILL_VERSION="${SKILL_VERSION:-1.2.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"

if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "emit-report: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

export FINDINGS_FILE TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR OUTPUT_BASENAME
export SKILL_NAME="magento2-module-upgrade"
export SKILL_VERSION
export OUTPUT_KIND="upgrade"
export SKILL_VERSIONS_JSON="[\"magento2-module-upgrade@${SKILL_VERSION}\",\"magento2-context@1.10.0\"]"

bash "$EMIT_FINDINGS"
