#!/usr/bin/env bash
# Smoke-test the context resolver. On a PHP-equipped host it must produce valid JSON
# whose `runner` honours the hub contract:
#   - runner_kind != "null"  (php on PATH means at least bare mode is detected)
#   - runner_kind == "bare"  =>  runner == ""  (empty STRING, never JSON null)
#       This is the CTX-1 regression guard: consumers compose `${runner} php -r ...`,
#       so a JSON null here produces the literal command `null php -r` (exit 127).
# theme.frontend must stay honest (null unless probe evidence exists).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v php >/dev/null 2>&1; then
    echo "skip: php not on PATH"
    exit 77
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
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

# --- Hub runner contract (CTX-1) ---------------------------------------------
# Use a single python pass so we can read several fields and distinguish JSON
# null from the empty string (which `jq -r` / shell cannot do cleanly).
python3 - "$OUT" <<'PY'
import sys, json
d = json.loads(sys.argv[1])
kind = d.get("runner_kind")
runner = d.get("runner")  # may be None (JSON null), "" (bare), or a command string

# php is on PATH (the bash guard above ensured it), so we expect a real runner_kind.
if kind in (None, "null"):
    print(f"FAIL: php on PATH but runner_kind={kind!r} (expected bare/docker-*)")
    sys.exit(1)

# CTX-1: a resolved runner_kind must never carry a JSON-null runner.
if runner is None:
    print(f"FAIL: runner_kind={kind!r} but runner serialized as JSON null (CTX-1)")
    sys.exit(1)

# Bare mode specifically must be the empty string.
if kind == "bare" and runner != "":
    print(f"FAIL: runner_kind=bare but runner={runner!r} (expected empty string)")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

# --- Theme honesty -----------------------------------------------------------
# REGRESSION TOMBSTONE: the resolver has no code path that emits "custom" for
# theme.frontend, so the old `THEME == custom` negative check could never fire.
# The real honesty invariant in an empty workspace is: frontend is null, OR it
# carries a non-empty frontend_source explaining the evidence.
python3 - "$OUT" <<'PY'
import sys, json
d = json.loads(sys.argv[1])
t = d.get("theme", {})
fe = t.get("frontend")
src = t.get("frontend_source") or ""
if fe is not None and not src:
    print(f"FAIL: theme.frontend={fe!r} with no frontend_source (honest-gap rule)")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

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
