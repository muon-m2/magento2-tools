#!/usr/bin/env bash
# Every .js template must parse with `node --check` after placeholder substitution.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v node >/dev/null 2>&1; then
    echo "skip: node not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.js)"
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor_lower}/acme/g' \
        -e 's/{vendor-lower}/acme/g' \
        -e 's/{vendorLower}/acme/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        -e 's/{moduleName}/mod/g' \
        -e 's/{module-kebab-case}/mod/g' \
        -e 's/{module-name-kebab}/mod/g' \
        -e 's/{Theme}/Theme/g' \
        -e 's/{theme-lower}/theme/g' \
        -e 's/{component}/component/g' \
        -e 's/{component-name-kebab}/component/g' \
        -e 's/{Entity}/Entity/g' \
        -e 's/{EntityName}/Entity/g' \
        "$tpl" > "$tmp"

    if ! node --check "$tmp" 2>/tmp/js-lint.err; then
        echo "FAIL: $tpl"
        sed 's/^/    /' /tmp/js-lint.err
        FAIL=1
    fi
    rm -f "$tmp" /tmp/js-lint.err
done < <(find .claude/skills -path '*/templates/*.js' -type f)

exit "$FAIL"
