#!/usr/bin/env bash
# test-dep-constraint.sh — contract test for the bounded-constraint resolver.
#
# magento2-context/scripts/resolve-dep-constraint.sh <vendor/package> [project_root] must:
#   - resolve a package version from composer.lock and print a bounded `>=MAJOR.MINOR.0` floor;
#   - strip a leading `v` from the locked version;
#   - never emit a wildcard `*`;
#   - exit non-zero (and print nothing) when the package cannot be resolved.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/magento2-context/scripts/resolve-dep-constraint.sh"
if [ ! -f "$SCRIPT" ]; then
    echo "FAIL: resolver not found at $SCRIPT"
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/m2-dep.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cat > "$work/composer.lock" <<'JSON'
{
    "packages": [
        { "name": "magento/module-eav", "version": "102.1.3" },
        { "name": "acme/foo", "version": "v1.4.2" }
    ]
}
JSON

# composer.json reuse path (only reached for packages absent from the lock):
# a bounded constraint is reused verbatim; a dev/wildcard constraint must be rejected.
cat > "$work/composer.json" <<'JSON'
{
    "require": {
        "bounded/pkg": "^2.0",
        "dev/pkg": "dev-master",
        "wild/pkg": "*"
    }
}
JSON

fail=0
assert_eq() { # <label> <actual> <expected>
    if [ "$2" != "$3" ]; then echo "FAIL: $1 — got '$2', expected '$3'"; fail=1; fi
}

# Strip composer-show preference for the test: force the lock path by running where no composer
# project is installed for these fake packages (composer show will miss them and fall through).
out="$(NO_COMPOSER=1 bash "$SCRIPT" magento/module-eav "$work" 2>/dev/null)"
assert_eq "eav floor" "$out" ">=102.1.0"

out="$(NO_COMPOSER=1 bash "$SCRIPT" acme/foo "$work" 2>/dev/null)"
assert_eq "v-prefixed floor" "$out" ">=1.4.0"

# composer.json reuse: a bounded constraint is reused verbatim.
out="$(NO_COMPOSER=1 bash "$SCRIPT" bounded/pkg "$work" 2>/dev/null)"
assert_eq "bounded reuse" "$out" "^2.0"

# composer.json reuse: a dev constraint must be REJECTED (exit non-zero, emit nothing).
if out="$(NO_COMPOSER=1 bash "$SCRIPT" dev/pkg "$work" 2>/dev/null)"; then
    echo "FAIL: 'dev-master' constraint must not be reused"; fail=1
fi
if [ -n "$out" ]; then echo "FAIL: dev constraint leaked output '$out'"; fail=1; fi

# composer.json reuse: a wildcard must be rejected too.
if out="$(NO_COMPOSER=1 bash "$SCRIPT" wild/pkg "$work" 2>/dev/null)"; then
    echo "FAIL: '*' constraint must not be reused"; fail=1
fi

# Unknown package → non-zero exit, no output, never a wildcard.
if out="$(NO_COMPOSER=1 bash "$SCRIPT" nope/missing "$work" 2>/dev/null)"; then
    echo "FAIL: unknown package must exit non-zero"; fail=1
fi
if printf '%s' "$out" | grep -q '[*]'; then
    echo "FAIL: resolver must never emit a wildcard"; fail=1
fi

[ "$fail" -eq 0 ] && echo "dep-constraint resolver: all assertions passed"
exit "$fail"
