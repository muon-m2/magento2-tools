#!/usr/bin/env bash
# test-template-orphan-use.sh — catch the formatter-corruption class that php -l misses.
#
# Some IDE PHP formatters mangle `use {Vendor}\{Module}\...;` import lines by dropping the
# `use {Vendor}` prefix, leaving an orphan `\{Module}\...;` statement. That is still
# SYNTACTICALLY valid PHP (a bare FQCN expression statement), so `php -l` passes — but the
# import is gone and the generated class is broken.
#
# Signature: a line that is ENTIRELY a `\{Ident}\...;` namespace path terminated by `;`.
# Multi-line method parameters also begin with `\{Vendor}\...` but carry a ` $var` and no
# trailing `;`, so they are not matched.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PATTERN='^[[:space:]]*\\\{[A-Za-z][A-Za-z0-9_\\{}]*;[[:space:]]*$'

FAILS=0
while IFS= read -r -d '' file; do
    if grep -nE "$PATTERN" "$file" >/dev/null 2>&1; then
        echo "FAIL: $file has an orphaned (prefix-stripped) use statement:"
        grep -nE "$PATTERN" "$file" | sed 's/^/    /'
        FAILS=$((FAILS + 1))
    fi
done < <(find skills -path '*/templates/*.php' -type f -print0)

if [ "$FAILS" -gt 0 ]; then
    echo "Restore the dropped 'use {Vendor}\\...;' prefix on the lines above."
    exit 1
fi
echo "no orphaned use statements in PHP templates"
exit 0
