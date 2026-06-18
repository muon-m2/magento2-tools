#!/usr/bin/env bash
# test-graphql-resolver-field-coverage.sh — every NON-NULL field on the generated GraphQL
# entity type must be returned by at least one resolver template. Regression guard for the
# audit's C1: schema-fragment.graphqls declared `status`/`created_at` as non-null (`!`) but no
# resolver returned them, so any client selecting those fields hit a runtime
# "Cannot return null for non-nullable field" error (the brace-balance shape test missed it).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

TPL="skills/magento2-graphql-create/templates"
SCHEMA="$TPL/schema-fragment.graphqls"
if [ ! -f "$SCHEMA" ]; then
    echo "skip: graphql schema fragment not found at $SCHEMA"
    exit 77
fi

python3 - "$SCHEMA" "$TPL" <<'PY'
import os
import re
import sys

schema_path, tpl_dir = sys.argv[1], sys.argv[2]
text = open(schema_path, encoding="utf-8").read()

# Isolate the `type {Entity} { ... }` object. The fields reference `{Entity}Status`, whose
# `}` is mid-line, so we must capture up to the closing brace at line start (`\n}`) — not the
# first `}` anywhere (which would truncate the body inside `{Entity}Status`).
m = re.search(r'type\s+\{Entity\}\s*\{\s*\n(.*?)\n\s*\}', text, re.DOTALL)
if not m:
    print(f"FAIL: could not find a `type {{Entity}} {{ ... }}` block in {schema_path}")
    sys.exit(1)
body = m.group(1)

# Non-null scalar/object fields look like `field: Type!` (the `!` is the non-null marker).
nonnull = []
for line in body.splitlines():
    fm = re.match(r'\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[\w\[\]{}]+!', line)
    if fm:
        nonnull.append(fm.group(1))

# Collect the keys every resolver template returns (`'key' => ...`).
returned = set()
for fname in os.listdir(tpl_dir):
    if fname.endswith("resolver.php"):
        rt = open(os.path.join(tpl_dir, fname), encoding="utf-8").read()
        for km in re.finditer(r"'([A-Za-z_][A-Za-z0-9_]*)'\s*=>", rt):
            returned.add(km.group(1))

missing = [f for f in nonnull if f not in returned]
if missing:
    print("FAIL: schema declares non-null {Entity} field(s) no resolver returns: "
          + ", ".join(missing))
    print("  Fix: make them nullable in schema-fragment.graphqls, or return them in the "
          "query/mutation/paginated/batch resolvers.")
    sys.exit(1)

print(f"all {len(nonnull)} non-null {{Entity}} field(s) are returned by a resolver"
      + (f": {', '.join(nonnull)}" if nonnull else ""))
sys.exit(0)
PY
