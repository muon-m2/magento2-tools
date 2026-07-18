#!/usr/bin/env bash
# resolve-context.sh resolves the Adobe Commerce B2B module version (magento/extension-b2b)
# into the context cache, but ONLY for enterprise-edition installs. A store without B2B (or
# on open-source) resolves b2b_version: null — never a fabricated value.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v php >/dev/null 2>&1 || { echo "skip: php"; exit 77; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3"; exit 77; }
RESOLVE="$(pwd)/skills/magento2-context/scripts/resolve-context.sh"

run_case() { # $1=composer.json $2=composer.lock  -> prints resolved b2b_version
    local d; d="$(mktemp -d)"
    printf '%s' "$1" > "$d/composer.json"
    printf '%s' "$2" > "$d/composer.lock"
    ( cd "$d" && bash "$RESOLVE" >/dev/null 2>&1 )
    python3 -c "import json;print(json.load(open('$d/.claude/.cache/magento2-context.json')).get('b2b_version'))" 2>/dev/null
    rm -rf "$d"
}

fail=0
CJ_EE='{"require":{"magento/product-enterprise-edition":"2.4.8"}}'
LOCK_B2B='{"packages":[{"name":"magento/extension-b2b","version":"1.3.5-p2"}]}'
LOCK_NOB2B='{"packages":[{"name":"magento/module-catalog","version":"104.0.0"}]}'
CJ_CE='{"require":{"magento/product-community-edition":"2.4.8"}}'

got="$(run_case "$CJ_EE" "$LOCK_B2B")"
[ "$got" = "1.3.5-p2" ] || { echo "FAIL: EE+extension-b2b -> b2b_version=$got, want 1.3.5-p2"; fail=1; }
got="$(run_case "$CJ_EE" "$LOCK_NOB2B")"
[ "$got" = "None" ] || { echo "FAIL: EE without B2B -> b2b_version=$got, want null"; fail=1; }
got="$(run_case "$CJ_CE" "$LOCK_B2B")"
[ "$got" = "None" ] || { echo "FAIL: open-source -> b2b_version=$got, want null (B2B is commerce-only)"; fail=1; }

[ "$fail" -eq 0 ] && echo "PASS: b2b_version resolution" || exit 1
