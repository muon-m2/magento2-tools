#!/usr/bin/env bash
# test-context-execution-mode.sh — `execution_mode` is a resolved context field, read
# from the plugin's own override file `.claude/m2.json` (NOT Claude Code's settings.json,
# which the plugin never parses and which silently accepts any key).
#
# Contract:
#   - absent / no m2.json            -> null            (no preference; skill default wins)
#   - "agents" | "inline" | "auto"   -> that value, resolution_source names the file
#   - any other value                -> null            (honest gap, never an invented mode)
#   - changing it busts the context cache (m2.json is already in the cache key)
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v php     >/dev/null 2>&1 || { echo "skip: php not on PATH";     exit 77; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r skills "$WORK/"

FAIL=0

# Resolve in an isolated tree with the given .claude/m2.json body ('' = no file at all),
# then print one field via python (no jq dependency).
resolve_field() {
    local m2_body="$1" field="$2"
    rm -rf "$WORK/.claude"
    if [ -n "$m2_body" ]; then
        mkdir -p "$WORK/.claude"
        printf '%s' "$m2_body" > "$WORK/.claude/m2.json"
    fi
    (cd "$WORK" && bash skills/context/scripts/resolve-context.sh --no-cache 2>/dev/null) \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
for part in '$field'.split('.'):
    d = d.get(part) if isinstance(d, dict) else None
print('null' if d is None else d)
"
}

check() {
    local label="$1" want="$2" got="$3"
    if [ "$got" != "$want" ]; then
        echo "FAIL: $label — expected '$want', got '$got'"
        FAIL=1
    fi
}

check "no m2.json -> null" \
      "null" "$(resolve_field '' 'execution_mode')"

check "m2.json without the key -> null" \
      "null" "$(resolve_field '{"magento_root":"."}' 'execution_mode')"

check "agents is honoured" \
      "agents" "$(resolve_field '{"execution_mode":"agents"}' 'execution_mode')"

check "inline is honoured" \
      "inline" "$(resolve_field '{"execution_mode":"inline"}' 'execution_mode')"
check "auto is honoured" \
      "auto" "$(resolve_field '{"execution_mode":"auto"}' 'execution_mode')"

check "an unknown mode degrades to null, never invented" \
      "null" "$(resolve_field '{"execution_mode":"parallel"}' 'execution_mode')"

check "a non-string value degrades to null" \
      "null" "$(resolve_field '{"execution_mode":true}' 'execution_mode')"

# A resolved value must say where it came from; an absent one must not claim a source.
src="$(resolve_field '{"execution_mode":"agents"}' 'resolution_source.execution_mode')"
case "$src" in
    *m2.json*) ;;
    *) echo "FAIL: resolution_source.execution_mode should name .claude/m2.json, got '$src'"; FAIL=1 ;;
esac
check "no source when unset" \
      "null" "$(resolve_field '' 'resolution_source.execution_mode')"

# Changing the mode must bust the cache rather than serve the previous run's value.
rm -rf "$WORK/.claude"
mkdir -p "$WORK/.claude"
printf '{"execution_mode":"agents"}' > "$WORK/.claude/m2.json"
(cd "$WORK" && bash skills/context/scripts/resolve-context.sh >/dev/null 2>&1)
printf '{"execution_mode":"inline"}' > "$WORK/.claude/m2.json"
after="$( (cd "$WORK" && bash skills/context/scripts/resolve-context.sh 2>/dev/null) \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("execution_mode") or "null")')"
check "editing m2.json busts the cache" "inline" "$after"

# The plugin must not have grown a settings.json read path: Claude Code accepts unknown
# keys there silently, so a stale instruction to read it would fail without any signal.
if grep -rn "settings\.json" skills/ 2>/dev/null | grep -viE 'not parsed|never parsed|do \*\*not\*\* read|NOT in Claude Code'; then
    echo "FAIL: skills/ still references settings.json for configuration"
    FAIL=1
fi

exit "$FAIL"
