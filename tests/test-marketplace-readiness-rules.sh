#!/usr/bin/env bash
# test-marketplace-readiness-rules.sh — false-positive guards for check-readiness.sh.
#   M9  unbounded constraint: platform packages (php, ext-*, lib-*, composer-*-api) use "*"
#       by convention and must not fire; a real package on "*" / "dev-main" still must.
#   MFTF missing: medium by default, info when PRIVATE_PACKAGE=1.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

CHECKER="${CHECKER:-$PWD/skills/marketplace/scripts/check-readiness.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0
ok() { echo "ok: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

mod="$WORK/Mod"
mkdir -p "$mod/etc"
cat > "$mod/etc/module.xml" <<'X'
<?xml version="1.0"?>
<config><module name="Acme_Mod"/></config>
X
cat > "$mod/composer.json" <<'X'
{
  "name": "acme/module-mod",
  "description": "Mod",
  "type": "magento2-module",
  "license": "proprietary",
  "version": "1.0.0",
  "require": {
    "php": "*",
    "php-64bit": "*",
    "ext-gd": "*",
    "ext-curl": "*",
    "lib-libxml": "*",
    "composer-plugin-api": "*",
    "composer-runtime-api": "*",
    "vendor/star": "*",
    "vendor/devbranch": "dev-main",
    "vendor/ok": "^1.0"
  },
  "autoload": {"psr-4": {"Acme\\Mod\\": ""}, "files": ["registration.php"]}
}
X

out="$(TARGET_PATH="$mod" bash "$CHECKER")"
titles() { printf '%s' "$out" | python3 -c 'import json,sys
for f in json.load(sys.stdin): print(f["severity"]+"|"+f["title"])'; }
t="$(titles)"

for pkg in php php-64bit ext-gd ext-curl lib-libxml composer-plugin-api composer-runtime-api; do
    if printf '%s\n' "$t" | grep -q "constraint in require: ${pkg}: "; then
        fail "platform package $pkg flagged as unbounded"
    else
        ok "platform package $pkg not flagged"
    fi
done
for pkg in vendor/star vendor/devbranch; do
    if printf '%s\n' "$t" | grep -q "^critical|Non-stable/unbounded version constraint in require: ${pkg}: "; then
        ok "control $pkg still critical"
    else
        fail "control $pkg no longer flagged"
    fi
done
printf '%s\n' "$t" | grep -q "require: vendor/ok:" && fail "bounded ^1.0 flagged" || ok "bounded ^1.0 not flagged"

printf '%s\n' "$t" | grep -q '^medium|MFTF functional tests not found' \
    && ok "MFTF missing is medium by default" || fail "MFTF missing not medium by default"

out="$(PRIVATE_PACKAGE=1 TARGET_PATH="$mod" bash "$CHECKER")"
t="$(titles)"
printf '%s\n' "$t" | grep -q '^info|MFTF functional tests not found' \
    && ok "MFTF missing is info when PRIVATE_PACKAGE=1" || fail "MFTF missing not info when PRIVATE_PACKAGE=1"

out="$(PRIVATE_PACKAGE=0 TARGET_PATH="$mod" bash "$CHECKER")"
t="$(titles)"
printf '%s\n' "$t" | grep -q '^medium|MFTF functional tests not found' \
    && ok "MFTF missing is medium when PRIVATE_PACKAGE=0" || fail "MFTF missing not medium when PRIVATE_PACKAGE=0"

mkdir -p "$mod/Test/Mftf/Test"
out="$(TARGET_PATH="$mod" bash "$CHECKER")"
t="$(titles)"
printf '%s\n' "$t" | grep -q 'MFTF functional tests not found' \
    && fail "MFTF flagged though Test/Mftf exists" || ok "MFTF present: no finding"

echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
