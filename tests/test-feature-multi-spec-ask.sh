#!/usr/bin/env bash
# test-feature-multi-spec-ask.sh — pins the multi-spec contract of /feature: a request naming
# several specs runs the first only, then asks (AskUserQuestion, /clear Recommended, printing
# the exact next command) instead of chaining specs in one conversation. The Phase 7 reference
# must point back at the rule so a model reading only it at 7B still asks.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
SKILL=skills/feature/SKILL.md
REF=skills/feature/references/phase7-docs-report.md

for token in 'more than one spec' 'AskUserQuestion' '/clear' '/magento2-tools:feature' 'Recommended'; do
    grep -qF -- "$token" "$SKILL" || { echo "FAIL: $SKILL lacks '$token'"; FAIL=1; }
done
grep -qF -- '/clear` and start fresh (Recommended)' "$SKILL" \
    || { echo "FAIL: $SKILL lacks the '/clear and start fresh (Recommended)' option"; FAIL=1; }
grep -qF -- 'Continue here' "$SKILL" || { echo "FAIL: $SKILL lacks the 'Continue here' option"; FAIL=1; }
grep -qF -- 'Multi-spec requests' "$REF" \
    || { echo "FAIL: $REF lacks the pointer back to the SKILL.md multi-spec rule"; FAIL=1; }

[ "$FAIL" -eq 0 ] && echo "PASS: feature multi-spec ask contract"
exit "$FAIL"
