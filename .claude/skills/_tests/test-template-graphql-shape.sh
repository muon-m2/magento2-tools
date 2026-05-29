#!/usr/bin/env bash
# Every .graphqls template must satisfy minimum structural checks:
#   - braces balance
#   - parentheses balance
#   - at least one top-level type/extend/scalar/interface/enum/input/schema decl
# This is a syntax sanity check, not a full GraphQL spec validator. Heavier validation
# would require a GraphQL parser dependency.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.graphqls)"
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor_lower}/acme/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        -e 's/{Entity}/Entity/g' \
        -e 's/{EntityName}/Entity/g' \
        "$tpl" > "$tmp"

    if ! python3 - "$tmp" "$tpl" <<'PY' 2>/tmp/gql-lint.err
import re
import sys

path = sys.argv[1]
src_path = sys.argv[2]
text = open(path, encoding='utf-8').read()

# Strip line comments so braces inside comments don't throw off counts.
stripped = re.sub(r'#[^\n]*', '', text)
# Strip GraphQL block strings ("""..."""), which may contain stray braces.
stripped = re.sub(r'"""[\s\S]*?"""', '', stripped)

opens, closes = stripped.count('{'), stripped.count('}')
if opens != closes:
    sys.stderr.write(f"brace imbalance: {opens} '{{' vs {closes} '}}' in {src_path}\n")
    sys.exit(1)

popens, pcloses = stripped.count('('), stripped.count(')')
if popens != pcloses:
    sys.stderr.write(f"paren imbalance: {popens} '(' vs {pcloses} ')' in {src_path}\n")
    sys.exit(1)

if not re.search(r'^\s*(type|extend|scalar|interface|enum|input|union|schema)\s', stripped, re.MULTILINE):
    sys.stderr.write(f"no top-level GraphQL declaration found in {src_path}\n")
    sys.exit(1)

sys.exit(0)
PY
    then
        echo "FAIL: $tpl"
        sed 's/^/    /' /tmp/gql-lint.err
        FAIL=1
    fi
    rm -f "$tmp" /tmp/gql-lint.err
done < <(find .claude/skills -path '*/templates/*.graphqls' -type f)

exit "$FAIL"
