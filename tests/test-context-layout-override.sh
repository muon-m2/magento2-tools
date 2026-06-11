#!/usr/bin/env bash
# test-context-layout-override.sh — resolver behaviour on a `src/` layout, with the
# M2_MAGENTO_ROOT override, and cache hit/invalidation. Guards CTX-5/CTX-6 regressions
# (vendor/magento_cli must not assume a repo-root layout).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

RESOLVER="$(pwd)/skills/magento2-context/scripts/resolve-context.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Stage a src/ layout fixture --------------------------------------------
mkdir -p "$WORK/src/app/code/Acme/Foo" "$WORK/src/bin"
: > "$WORK/src/bin/magento"
cat > "$WORK/src/composer.json" <<'JSON'
{ "require": { "magento/product-community-edition": "2.4.7", "php": "~8.2.0" } }
JSON

get() { # get <json-file> <dotted.path>
    python3 -c "import json,sys; d=json.load(open(sys.argv[1]))
p=sys.argv[2].split('.')
v=d
for k in p:
    v=v.get(k) if isinstance(v,dict) else None
print(v if v is not None else '')" "$1" "$2"
}

OUT1="$WORK/out1.json"
(cd "$WORK" && bash "$RESOLVER" --no-cache > "$OUT1" 2>/dev/null)

ROOT="$(get "$OUT1" magento_root)"
MODDIR="$(get "$OUT1" module_dir)"
VENDOR="$(get "$OUT1" vendor)"

if [ "$ROOT" != "src" ]; then
    echo "FAIL: src layout magento_root='$ROOT' (expected 'src')"; exit 1
fi
if [ "$MODDIR" != "src/app/code" ]; then
    echo "FAIL: src layout module_dir='$MODDIR' (expected 'src/app/code')"; exit 1
fi
if [ "$VENDOR" != "Acme" ]; then
    echo "FAIL: src layout vendor='$VENDOR' (expected 'Acme' from the single non-Magento dir)"; exit 1
fi

# --- M2_MAGENTO_ROOT override -----------------------------------------------
OUT2="$WORK/out2.json"
(cd "$WORK" && M2_MAGENTO_ROOT="custom-root" bash "$RESOLVER" --no-cache > "$OUT2" 2>/dev/null)
OROOT="$(get "$OUT2" magento_root)"
if [ "$OROOT" != "custom-root" ]; then
    echo "FAIL: M2_MAGENTO_ROOT override not honoured (got '$OROOT')"; exit 1
fi

# --- Cache hit: a second cached run returns the identical document -----------
OUT3="$WORK/out3.json"
OUT4="$WORK/out4.json"
(cd "$WORK" && bash "$RESOLVER" > "$OUT3" 2>/dev/null)   # writes cache
(cd "$WORK" && bash "$RESOLVER" > "$OUT4" 2>/dev/null)   # should be a cache hit
if ! diff -q "$OUT3" "$OUT4" >/dev/null; then
    echo "FAIL: two cached runs differ (cache not stable)"; exit 1
fi

# --- Cache invalidation: changing composer.json busts the key ----------------
KEY_BEFORE="$(get "$OUT3" cacheKey)"
cat > "$WORK/src/composer.json" <<'JSON'
{ "require": { "magento/product-enterprise-edition": "2.4.8", "php": "~8.3.0" } }
JSON
OUT5="$WORK/out5.json"
(cd "$WORK" && bash "$RESOLVER" > "$OUT5" 2>/dev/null)
KEY_AFTER="$(get "$OUT5" cacheKey)"
if [ "$KEY_BEFORE" = "$KEY_AFTER" ]; then
    echo "FAIL: cacheKey unchanged after composer.json edit (stale cache)"; exit 1
fi

exit 0
