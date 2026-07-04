#!/usr/bin/env bash
# One screenshots convention: docs-generate's appendix points at docs/screenshots/ (not docs/images/).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DS=skills/magento2-docs-generate/references/doc-structure.md
FAIL=0
grep -q 'docs/screenshots/' "$DS" || { echo "FAIL: doc-structure.md does not use docs/screenshots/"; FAIL=1; }
grep -q 'docs/images/' "$DS" && { echo "FAIL: doc-structure.md still references the old docs/images/ path"; FAIL=1; }
exit "$FAIL"
