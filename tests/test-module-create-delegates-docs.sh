#!/usr/bin/env bash
# module-create delegates its doc set to docs-generate and no longer ships its own
# README template / hand-written guide procedures.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
FAIL=0

[ ! -f skills/magento2-module-create/templates/README.md ] \
    || { echo "FAIL: module-create still ships templates/README.md"; FAIL=1; }

# Step 6 / documentation-guide must delegate the full set to docs-generate (not just technical-reference).
grep -q 'magento2-docs-generate' skills/magento2-module-create/references/documentation-guide.md \
    || { echo "FAIL: documentation-guide does not delegate to docs-generate"; FAIL=1; }

exit "$FAIL"
