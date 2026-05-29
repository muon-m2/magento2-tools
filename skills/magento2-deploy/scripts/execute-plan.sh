#!/usr/bin/env bash
# execute-plan.sh — run a deploy plan step by step, log each result.
#
# Inputs:
#   PLAN_FILE     Path to a text file with one shell command per non-blank, non-comment line.
#   OUTPUT_FILE   Where to append per-step JSON results.
#
# Behaviour:
#   - Runs each command in order.
#   - Captures exit code, stdout (head 1000 chars), stderr (head 1000 chars), duration.
#   - On non-zero exit: stops and exits non-zero — caller should invoke rollback.
#
# Output format (line per step):
#   {"step":1,"command":"...","exit":0,"duration_ms":N,"stdout":"...","stderr":"..."}

set -uo pipefail

PLAN_FILE="${PLAN_FILE:?PLAN_FILE is required}"
OUTPUT_FILE="${OUTPUT_FILE:-/dev/null}"

: > "$OUTPUT_FILE"
n=0

while IFS= read -r line; do
    case "$line" in
        ''|'#'*) continue ;;
    esac
    n=$((n + 1))
    start_ms="$(date +%s%3N)"
    out_file="$(mktemp)"; err_file="$(mktemp)"
    bash -c "$line" >"$out_file" 2>"$err_file"
    exit_code=$?
    end_ms="$(date +%s%3N)"
    duration=$((end_ms - start_ms))
    stdout="$(head -c 1000 "$out_file" | tr '\n' ' ' | sed 's/"/\\"/g')"
    stderr="$(head -c 1000 "$err_file" | tr '\n' ' ' | sed 's/"/\\"/g')"
    rm -f "$out_file" "$err_file"
    json=$(printf '{"step":%d,"command":"%s","exit":%d,"duration_ms":%d,"stdout":"%s","stderr":"%s"}' \
        "$n" "${line//\"/\\\"}" "$exit_code" "$duration" "$stdout" "$stderr")
    echo "$json" | tee -a "$OUTPUT_FILE"
    if [ "$exit_code" -ne 0 ]; then
        echo "execute-plan: step $n exited $exit_code — stopping" >&2
        exit "$exit_code"
    fi
done < "$PLAN_FILE"

echo "execute-plan: completed $n steps" >&2
