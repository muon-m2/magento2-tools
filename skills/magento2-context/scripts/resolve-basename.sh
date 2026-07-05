#!/usr/bin/env bash
# resolve-basename.sh — compute OUTPUT_BASENAME for an audit-builder wrapper.
#
# Shared by the six audit build-findings.sh wrappers (security/perf/quality/
# marketplace-prep/accessibility/breeze-compat) to avoid duplicating the
# module-vs-scope basename branch that each one previously inlined.
#
# Usage:
#   OUTPUT_BASENAME="$(bash resolve-basename.sh <kind>)"
#
# Inputs (env vars):
#   SCOPE          "module" (default) | "site" | "diff" | "vendor" | "theme"
#   TARGET_MODULE  required when SCOPE=module, e.g. "Acme_OrderS3Export"
#   DATE           required, e.g. "2026-07-04" (YYYY-MM-DD, UTC)
#
# Args:
#   $1  kind — the audit-specific token, e.g. "security", "perf", "quality",
#       "readiness", "a11y", "breeze-compat".
#
# Output:
#   Echoes "${TARGET_MODULE}-<kind>-${DATE}" for module scope, otherwise
#   "<kind>-${SCOPE}-${DATE}".

set -euo pipefail

KIND="${1:?resolve-basename: kind argument is required (e.g. security, perf, quality)}"
SCOPE="${SCOPE:-module}"
: "${DATE:?DATE is required}"

if [ "$SCOPE" = "module" ]; then
    : "${TARGET_MODULE:?TARGET_MODULE is required when SCOPE=module}"
    echo "${TARGET_MODULE}-${KIND}-${DATE}"
else
    echo "${KIND}-${SCOPE}-${DATE}"
fi
