#!/usr/bin/env bash
# test-agent-routing.sh — every agents/*.md must be a well-formed agent: a CLOSED YAML frontmatter
# block (opening + closing `---`) declaring name + description + tools. Review/audit agents must be
# READ-ONLY — no Write/Edit/NotebookEdit among their tools, inline OR YAML-list form. And every
# ${CLAUDE_PLUGIN_ROOT}/skills/.../*.md path the agent cites must resolve to a real file.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ -d agents ] || { echo "skip: no agents/ directory"; exit 77; }

PREFIX='${CLAUDE_PLUGIN_ROOT}/'
FAIL=0

for f in agents/*.md; do
    [ -e "$f" ] || continue

    # Extract the YAML frontmatter block — content between the opening `---` (line 1) and the next
    # `---`. awk exits 2 if line 1 isn't `---`, 3 if the block is never closed (unterminated).
    fm="$(awk '
        NR==1 { if ($0 != "---") exit 2; next }
        $0 == "---" { closed=1; exit }
        { print }
        END { if (!closed) exit 3 }
    ' "$f")"
    case $? in
        2) echo "FAIL: $f missing opening '---' frontmatter"; FAIL=1; continue ;;
        3) echo "FAIL: $f frontmatter is not closed with '---'"; FAIL=1; continue ;;
    esac

    printf '%s\n' "$fm" | grep -qE '^name: +.+'    || { echo "FAIL: $f missing non-empty name"; FAIL=1; }
    printf '%s\n' "$fm" | grep -qE '^description:' || { echo "FAIL: $f missing description"; FAIL=1; }
    printf '%s\n' "$fm" | grep -qE '^tools:'        || { echo "FAIL: $f missing tools"; FAIL=1; }

    # read-only enforcement: a review/audit agent must not declare a write tool. Scope to the
    # `tools:` declaration (its line + any indented list items), so the YAML-list form is covered.
    if grep -qiE 'review|audit' "$f"; then
        tools_block="$(printf '%s\n' "$fm" | awk '/^tools:/{t=1;print;next} t&&/^[A-Za-z_-]+:/{t=0} t{print}')"
        if printf '%s\n' "$tools_block" | grep -qE '(Write|Edit|NotebookEdit)'; then
            echo "FAIL: $f is a review/audit agent but declares a write tool"; FAIL=1
        fi
    fi

    # every ${CLAUDE_PLUGIN_ROOT}/skills/... reference must resolve to a real file
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        rel="${ref#"$PREFIX"}"
        [ -f "$rel" ] || { echo "FAIL: $f references a missing path: $ref"; FAIL=1; }
    done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/skills/[A-Za-z0-9/_.-]+\.md' "$f" | sort -u)
done

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "agents: valid closed frontmatter, read-only review agents, resolvable references"
exit 0
