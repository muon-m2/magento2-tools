#!/usr/bin/env bash
# execute-plan.sh must run EVERY step of a plan, including the steps after one that reads stdin.
#
# Regression test for a silent deploy bypass. The step loop read the plan on stdin
# (`done < "$PLAN_FILE"`) and every step inherited that same stdin. `docker compose exec -T` — the
# default {ctx.runner} for Docker projects — reads stdin, so the first runner step drained the rest
# of the plan, the next `read` hit EOF, and the script printed "completed 1 steps" and exited 0.
# Observed on a real deploy: module:status → cache:flush → indexer:status ran module:status only,
# and a plan whose later steps were setup:upgrade would have skipped them with no error.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/deploy/scripts/execute-plan.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }

# Step 1 stands in for `docker compose exec -T …`: it drains whatever stdin it was given. A comment
# and a blank line sit between the steps, because the loop must keep skipping those as well.
printf '%s\n' 'cat >/dev/null' '# not a step' '' 'echo step-two' 'echo step-three' > "$WORK/plan.txt"

PLAN_FILE="$WORK/plan.txt" OUTPUT_FILE="$WORK/steps.jsonl" \
    bash "$SCRIPT" >/dev/null 2>"$WORK/stderr.txt" </dev/null
rc=$?

steps="$(wc -l < "$WORK/steps.jsonl" | tr -d ' ')"

[ "$rc" = "0" ] || fail "exit $rc, expected 0"
[ "$steps" = "3" ] || fail "$steps JSONL line(s) written, expected 3 — steps after the stdin reader were dropped"
grep -q 'completed 3 steps' "$WORK/stderr.txt" \
    || fail "summary does not report 3 completed steps: $(cat "$WORK/stderr.txt")"
grep -q '"step":3,"command":"echo step-three","exit":0' "$WORK/steps.jsonl" \
    || fail "step 3 did not run to exit 0"

if [ "$FAIL" = "0" ]; then
    echo "PASS: execute-plan runs every step even when one of them reads stdin"
    exit 0
fi
echo "--- steps.jsonl ---"; cat "$WORK/steps.jsonl"
exit 1
