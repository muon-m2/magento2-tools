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

# Portable epoch-milliseconds. GNU `date +%s%3N` is not supported on BSD/macOS date (no %N),
# where it would emit a non-numeric string and corrupt the duration arithmetic. Fall back to
# python3, then to whole-second precision.
now_ms() {
    local t
    t="$(date +%s%3N 2>/dev/null)"
    if [[ "$t" =~ ^[0-9]+$ ]]; then
        printf '%s' "$t"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import time; print(int(time.time()*1000))'
    else
        printf '%s000' "$(date +%s)"
    fi
}

: > "$OUTPUT_FILE"
n=0

while IFS= read -r line; do
    case "$line" in
        ''|'#'*) continue ;;
    esac
    n=$((n + 1))
    start_ms="$(now_ms)"
    out_file="$(mktemp)"; err_file="$(mktemp)"
    bash -c "$line" >"$out_file" 2>"$err_file"
    exit_code=$?
    end_ms="$(now_ms)"
    duration=$((end_ms - start_ms))
    # Escape backslashes BEFORE quotes — a PHP namespace (Vendor\Module) in the output
    # otherwise produced invalid JSON (DEP-6). tr drops CR; newlines already collapsed.
    stdout="$(head -c 1000 "$out_file" | tr '\n' ' ' | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    stderr="$(head -c 1000 "$err_file" | tr '\n' ' ' | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    rm -f "$out_file" "$err_file"
    cmd_esc="${line//\\/\\\\}"   # backslashes first
    cmd_esc="${cmd_esc//\"/\\\"}"  # then quotes
    json=$(printf '{"step":%d,"command":"%s","exit":%d,"duration_ms":%d,"stdout":"%s","stderr":"%s"}' \
        "$n" "$cmd_esc" "$exit_code" "$duration" "$stdout" "$stderr")
    echo "$json" | tee -a "$OUTPUT_FILE"
    if [ "$exit_code" -ne 0 ]; then
        echo "execute-plan: step $n exited $exit_code — stopping" >&2
        exit "$exit_code"
    fi
done < "$PLAN_FILE"

echo "execute-plan: completed $n steps" >&2
