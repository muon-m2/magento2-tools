#!/usr/bin/env bash
# Every .json template must parse with `python3 -m json.tool` after placeholder substitution.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.json)"
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor_lower}/acme/g' \
        -e 's/{vendor-lower}/acme/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        -e 's/{module-kebab-case}/mod/g' \
        -e 's/{module-name-kebab}/mod/g' \
        -e 's/{Theme}/Theme/g' \
        -e 's/{theme-lower}/theme/g' \
        -e 's/{Entity}/Entity/g' \
        -e 's/{EntityName}/Entity/g' \
        -e 's/{php_constraint}/~8.2.0/g' \
        -e 's/{framework_constraint}/103.0.7/g' \
        -e 's|{Short, meaningful description of what this module does}|Module description|g' \
        "$tpl" > "$tmp"

    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$tmp" 2>/tmp/json-parse.err; then
        echo "FAIL: $tpl"
        sed 's/^/    /' /tmp/json-parse.err
        FAIL=1
    fi
    rm -f "$tmp" /tmp/json-parse.err
done < <(find skills -path '*/templates/*.json' -type f)

exit "$FAIL"
