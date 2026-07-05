#!/usr/bin/env bash
# compute-readiness-score.sh — POST_JSON_HOOK for the shared emit-findings.sh pipeline.
#
# Injects the `readiness_score` and `readiness_verdict` fields into the emitted marketplace
# JSON, derived from finding severities. Runs after emit-json.sh and before emit-sarif.sh.
#
# Usage (invoked by emit-findings.sh):
#   bash compute-readiness-score.sh <output-json-file>
#
# scanner_errors is already included by emit-json.sh via SCANNER_ERRORS_FILE — this hook
# only adds the readiness score/verdict.

set -uo pipefail

OUTPUT_FILE="${1:?usage: compute-readiness-score.sh <output-json-file>}"
[ -f "$OUTPUT_FILE" ] || exit 0

python3 - "$OUTPUT_FILE" <<'PY'
import json
import sys

doc_path = sys.argv[1]
with open(doc_path) as fh:
    doc = json.load(fh)

# Compute readiness score from findings.
severity_weight = {'critical': 25, 'high': 15, 'medium': 5, 'low': 1, 'info': 0}
score = 100
blocker_count = 0
for f in doc.get('findings', []):
    sev = f.get('severity', 'info')
    score -= severity_weight.get(sev, 0)
    if sev in ('critical', 'high'):
        blocker_count += 1

score = max(score, 0)

if blocker_count > 0:
    verdict = "FAIL"
elif score >= 85:
    verdict = "PASS"
else:
    verdict = "CONDITIONAL"

doc['readiness_score'] = score
doc['readiness_verdict'] = verdict

with open(doc_path, 'w') as fh:
    json.dump(doc, fh, indent=2)
PY
