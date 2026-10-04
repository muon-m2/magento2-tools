#!/usr/bin/env bash
# test-phase-references.sh — pins the phase-reference contract for slimmed skills: every
# skills/*/references/*.md whose header says "Part of the `<skill>` skill — read at …" must
# (a) name the skill whose directory it lives in, (b) be cited by that skill's SKILL.md as
# `references/<file>.md`, and (c) sit under a SKILL.md whose "## Core Rules" section carries the
# "After a context compaction" re-read bullet — otherwise a compacted session never re-reads it.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
COUNT=0
for ref in skills/*/references/*.md; do
    head -n 5 "$ref" | grep -qF 'Part of the `' || continue
    hdr=$(head -n 5 "$ref" | grep -F 'Part of the `' | head -n 1)
    [[ "$hdr" == *'skill — read at'* ]] || continue
    COUNT=$((COUNT + 1))
    dir=$(basename "$(dirname "$(dirname "$ref")")")
    file=$(basename "$ref")
    named=$(printf '%s' "$hdr" | sed -n 's/.*Part of the `\([^`]*\)` skill.*/\1/p')
    skill_md="skills/$dir/SKILL.md"
    [[ "$named" == "$dir" ]] || echo "FAIL: $ref header names skill '$named', lives under '$dir'"
    [[ "$named" == "$dir" ]] || FAIL=1
    if [[ ! -f "$skill_md" ]]; then echo "FAIL: $skill_md missing for $ref"; FAIL=1; continue; fi
    grep -qF "\`references/$file\`" "$skill_md" \
        || { echo "FAIL: $skill_md does not cite \`references/$file\`"; FAIL=1; }
    awk '/^## Core Rules/{f=1;next} /^## /{f=0} f' "$skill_md" | grep -qF 'After a context compaction' \
        || { echo "FAIL: $skill_md Core Rules lack the 'After a context compaction' bullet (needed by $file)"; FAIL=1; }
done
[[ "$COUNT" -gt 0 ]] || { echo "FAIL: no phase references found (header pattern drifted?)"; FAIL=1; }
exit "$FAIL"
