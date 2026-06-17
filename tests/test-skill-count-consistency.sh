#!/usr/bin/env bash
# test-skill-count-consistency.sh — prose skill counts must match the skills on disk.
#
# The README and developer docs state how many skills the plugin ships (e.g. "18 skills",
# "18 magento2-* skills", "18 *skills*"). That count drifts every time a skill is added.
# This test pins every such claim in the *tracked* docs to the actual number of directories
# under skills/.
#
# Scope: README.md + docs/*.md only. Deliberately EXCLUDES:
#   - CHANGELOG.md and .docs/* — dated snapshots where an older count was true when written.
#   - "N templates" / "N files" — not skill counts (they don't contain the word "skills").
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

ACTUAL=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$ACTUAL" -eq 0 ]; then
    echo "FAIL: no skills found under skills/"
    exit 1
fi

DOCS=(
    README.md
    docs/README.md
    docs/getting-started.md
    docs/daily-workflows.md
    docs/new-project-guide.md
    docs/flows-and-scenarios.md
    docs/skills-reference.md
    docs/configuration.md
)

# Matches: "<N> skills", "<N> magento2-* skills", "<N> *skills*" (markdown emphasis).
PATTERN='[0-9]+ +\*?(magento2-\* +)?\*?skills?\*?'

fail=0
checked=0
for f in "${DOCS[@]}"; do
    [ -f "$f" ] || continue
    matches=$(grep -niE "$PATTERN" "$f" || true)
    [ -z "$matches" ] && continue
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        lineno=${m%%:*}
        rest=${m#*:}
        n=$(printf '%s' "$rest" | grep -oiE "$PATTERN" | grep -oE '[0-9]+' | head -1)
        checked=$((checked + 1))
        if [ "$n" != "$ACTUAL" ]; then
            echo "FAIL: $f:$lineno claims '$n skills' but $ACTUAL skills exist on disk"
            echo "    > $(printf '%s' "$rest" | sed 's/^[[:space:]]*//')"
            fail=1
        fi
    done <<< "$matches"
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "skill-count consistent: $checked claim(s) across tracked docs all == $ACTUAL skills"
exit 0
