#!/usr/bin/env bash
# Every .csv template must parse with Python's csv module after placeholder substitution.
# Magento i18n CSV expects 2 columns per row; we enforce that as a structural rule.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.csv)"
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor_lower}/acme/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        "$tpl" > "$tmp"

    if ! python3 - "$tmp" "$tpl" <<'PY' 2>/tmp/csv-lint.err
import csv
import sys

tmp_path, src_path = sys.argv[1], sys.argv[2]
errors = []
with open(tmp_path, newline='', encoding='utf-8') as fh:
    reader = csv.reader(fh)
    for i, row in enumerate(reader, start=1):
        if not row:
            continue
        if len(row) != 2:
            errors.append(f"row {i} has {len(row)} columns (expected 2): {row[:3]!r}")
if errors:
    for e in errors:
        sys.stderr.write(f"{src_path}: {e}\n")
    sys.exit(1)
sys.exit(0)
PY
    then
        echo "FAIL: $tpl"
        sed 's/^/    /' /tmp/csv-lint.err
        FAIL=1
    fi
    rm -f "$tmp" /tmp/csv-lint.err
done < <(find .claude/skills -path '*/templates/*.csv' -type f)

exit "$FAIL"
