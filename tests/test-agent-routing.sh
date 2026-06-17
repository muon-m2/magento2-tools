#!/usr/bin/env bash
# test-agent-routing.sh — every agents/*.md must be a well-formed agent (name + description +
# tools frontmatter); review/audit agents must be READ-ONLY (no Write/Edit); and any
# ${CLAUDE_PLUGIN_ROOT}/skills/.../*.md path the agent cites must resolve to a real file.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ -d agents ] || { echo "skip: no agents/ directory"; exit 0; }

PREFIX='${CLAUDE_PLUGIN_ROOT}/'
FAIL=0

for f in agents/*.md; do
    [ -e "$f" ] || continue
    [ "$(head -1 "$f")" = "---" ] || { echo "FAIL: $f missing YAML frontmatter"; FAIL=1; }
    grep -qE '^name: +.+' "$f"        || { echo "FAIL: $f missing non-empty name"; FAIL=1; }
    grep -qE '^description:' "$f"     || { echo "FAIL: $f missing description"; FAIL=1; }
    grep -qE '^tools:' "$f"          || { echo "FAIL: $f missing tools"; FAIL=1; }

    # review/audit agents are read-only — must not list a write tool
    if grep -qiE 'review|audit' "$f"; then
        if grep -E '^tools:' "$f" | grep -qE '(Write|Edit|NotebookEdit)'; then
            echo "FAIL: $f is a review/audit agent but lists a write tool"; FAIL=1
        fi
    fi

    # every ${CLAUDE_PLUGIN_ROOT}/skills/... reference must resolve
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        rel="${ref#"$PREFIX"}"
        [ -f "$rel" ] || { echo "FAIL: $f references a missing path: $ref"; FAIL=1; }
    done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/skills/[A-Za-z0-9/_.-]+\.md' "$f" | sort -u)
done

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "agents: valid frontmatter, read-only review agents, resolvable references"
exit 0
