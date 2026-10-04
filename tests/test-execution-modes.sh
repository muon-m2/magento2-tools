#!/usr/bin/env bash
# test-execution-modes.sh — the 2.0 execution-mode contract: one canonical reference
# defines mode selection; every audit/RCA-family skill cites it, names its default,
# and the mode flags are exposed on the matching commands. Gates stay in the main
# conversation in both modes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
CANON=skills/context/references/execution-modes.md

[ -f "$CANON" ] || { echo "FAIL: $CANON missing"; exit 1; }
for token in '--agents' '--inline' 'execution_mode' '.claude/m2.json' 'in precedence order' \
             'Approval gates always run in the main conversation' \
             '`auto` resolution' 'context-budget' 'MAGENTO2_TOOLS_CTX_WARN' \
             'Pass `model` on every `Agent` call'; do
    grep -qF -- "$token" "$CANON" || { echo "FAIL: canon lacks '$token'"; FAIL=1; }
done
# The per-project setting lives in the plugin's own override file, which the resolver
# actually parses — not in Claude Code's settings.json, which it never reads and which
# accepts any key silently. The canon must show the literal JSON shape, because a dotted
# key name alone leaves a reader guessing between nested and flat.
grep -qF -- '{ "execution_mode": "agents" }' "$CANON" \
    || { echo "FAIL: canon must show the literal .claude/m2.json shape"; FAIL=1; }
grep -qF -- 'm2.executionMode' "$CANON" \
    && { echo "FAIL: canon still names the retired settings.json key m2.executionMode"; FAIL=1; }
# The resolver must expose it as a context field, so the seven consumers read it once
# from the Phase 0 context document instead of each parsing a file themselves.
grep -qF -- '"execution_mode"' skills/context/scripts/resolve-context.sh \
    || { echo "FAIL: resolve-context.sh does not emit an execution_mode field"; FAIL=1; }
# The two agents the contract dispatches must exist.
for a in reviewer explorer; do
    [ -f "agents/$a.md" ] || { echo "FAIL: agents/$a.md missing"; FAIL=1; }
done

# Every consumer cites the canon and names its default.
declare -A DEFAULT=(
    [audit]=agents [review]=auto [security]=auto [perf-audit]=auto
    [a11y-audit]=auto [marketplace]=auto [fix]=auto
)
for skill in "${!DEFAULT[@]}"; do
    md="skills/$skill/SKILL.md"
    grep -q 'context/references/execution-modes.md' "$md" \
        || { echo "FAIL: $md does not cite the execution-modes canon"; FAIL=1; }
    case "${DEFAULT[$skill]}" in
        agents) grep -qE 'Default: \*\*agents\*\*' "$md" \
            || { echo "FAIL: $md must state default agents"; FAIL=1; } ;;
        auto) grep -qiE 'default is \*\*auto\*\*|Default: \*\*auto\*\*' "$md" \
            || { echo "FAIL: $md must state default auto"; FAIL=1; } ;;
    esac
done

# The RCA gate stays in the main conversation in either mode.
grep -q 'approval gate below always runs in the main' skills/fix/SKILL.md \
    || { echo "FAIL: fix must pin the RCA gate to the main conversation"; FAIL=1; }

# Commands expose the flags.
for cmd in audit review security perf bugfix; do
    grep -q -- '--agents|--inline' "commands/$cmd.md" \
        || { echo "FAIL: commands/$cmd.md argument-hint lacks --agents|--inline"; FAIL=1; }
done

exit "$FAIL"
