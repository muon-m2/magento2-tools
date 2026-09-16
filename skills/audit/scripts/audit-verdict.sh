#!/usr/bin/env bash
# audit-verdict.sh — POST_JSON_HOOK for consolidate.sh's emit-findings.sh invocation.
#
# Injects whichever of the audit's non-findings top-level fields META_FILE carries, between
# JSON emission and SARIF so they land in JSON only. consolidate.sh supplies `audit_verdict`,
# `audit_score` and `dimension_coverage`; compare-findings.sh supplies `closure`,
# `verdict_delta`, `score_delta` and `baseline_report`. No-op when META_FILE is unset/missing.
#
# Usage (invoked by emit-findings.sh):
#   META_FILE=<meta.json> bash audit-verdict.sh <output-json-file>

set -uo pipefail

OUTPUT_FILE="${1:?usage: audit-verdict.sh <output-json-file>}"
[ -f "$OUTPUT_FILE" ] || exit 0
META_FILE="${META_FILE:-}"
[ -n "$META_FILE" ] && [ -f "$META_FILE" ] || exit 0

META_FILE="$META_FILE" python3 - "$OUTPUT_FILE" <<'PY'
import json, os, sys
doc_path = sys.argv[1]
with open(doc_path) as fh:
    doc = json.load(fh)
with open(os.environ['META_FILE']) as fh:
    meta = json.load(fh)
# consolidate.sh contributes the first three; compare-findings.sh the closure keys.
# One hook, driven entirely by what META_FILE actually contains.
for k in ('audit_verdict', 'audit_score', 'dimension_coverage',
          'closure', 'verdict_delta', 'score_delta', 'baseline_report'):
    if k in meta:
        doc[k] = meta[k]
with open(doc_path, 'w') as fh:
    json.dump(doc, fh, indent=2)
PY
