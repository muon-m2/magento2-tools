#!/usr/bin/env bash
# Smoke-test the context resolver: with bare PHP only, it must produce valid JSON
# whose `runner` is non-null and whose `theme.frontend` is honest (null unless
# probed evidence exists).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v php >/dev/null 2>&1; then
    echo "skip: php not on PATH"
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

# Run in an isolated tempdir so cache state doesn't pollute the result.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r skills "$WORK/" 2>/dev/null || true
rm -rf "$WORK/.claude/.cache" 2>/dev/null || true

OUT="$(cd "$WORK" && bash skills/magento2-context/scripts/resolve-context.sh --no-cache 2>/dev/null || true)"

if [ -z "$OUT" ]; then
    echo "FAIL: resolver produced no output"
    exit 1
fi

if ! echo "$OUT" | python3 -c 'import sys, json; json.loads(sys.stdin.read())' 2>/dev/null; then
    echo "FAIL: resolver output is not valid JSON"
    echo "$OUT" | head -5
    exit 1
fi

# theme.frontend must NOT silently default to "custom" when no probe evidence exists.
THEME=$(echo "$OUT" | python3 -c 'import sys, json; d=json.loads(sys.stdin.read()); print(d.get("theme", {}).get("frontend"))')
if [ "$THEME" = "custom" ]; then
    SRC=$(echo "$OUT" | python3 -c 'import sys, json; d=json.loads(sys.stdin.read()); print(d.get("theme", {}).get("frontend_source") or "")')
    if [ -z "$SRC" ]; then
        echo "FAIL: theme.frontend defaulted to 'custom' with no frontend_source"
        exit 1
    fi
fi

# php_version, when present, must include a source.
PV=$(echo "$OUT" | python3 -c 'import sys, json; d=json.loads(sys.stdin.read()); print(d.get("php_version") or "")')
if [ -n "$PV" ] && [ "$PV" != "null" ]; then
    PV_SRC=$(echo "$OUT" | python3 -c 'import sys, json; d=json.loads(sys.stdin.read()); print(d.get("resolution_source", {}).get("php_version") or "")')
    if [ -z "$PV_SRC" ]; then
        echo "FAIL: php_version=$PV but resolution_source.php_version missing"
        exit 1
    fi
fi

exit 0
