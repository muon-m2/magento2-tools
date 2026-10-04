#!/usr/bin/env bash
# test-output-budget.sh — pins the output-budget contract: one shared reference states the
# seven read/output rules, and the ten heavy run skills cite it from inside their
# `## Core Rules` section (a citation elsewhere in the file does not count).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
REF=skills/context/references/output-budget.md

[ -f "$REF" ] || { echo "FAIL: $REF missing"; exit 1; }
for token in 'Locate, then read a range' 'read once' 'summary first' 'Long outputs go to a file' \
             'Write tool' 'read the section, not the file' 'summaries, not page dumps'; do
    grep -qF -- "$token" "$REF" || { echo "FAIL: $REF lacks '$token'"; FAIL=1; }
done

for skill in feature fix remediate upgrade deploy docs lint test-generate review audit; do
    f="skills/$skill/SKILL.md"
    [ -f "$f" ] || { echo "FAIL: $f missing"; FAIL=1; continue; }
    section=$(awk '/^## Core Rules/{f=1;next} f&&/^## /{exit} f' "$f")
    printf '%s\n' "$section" | grep -qF -- 'context/references/output-budget.md' \
        || { echo "FAIL: $f Core Rules does not cite context/references/output-budget.md"; FAIL=1; }
done

[ "$FAIL" -eq 0 ] && echo "PASS: output-budget reference + 10 citations"
exit "$FAIL"
