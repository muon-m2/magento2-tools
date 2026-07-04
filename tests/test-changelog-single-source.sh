#!/usr/bin/env bash
# One canonical CHANGELOG format; the other CHANGELOG-producing skills cite it, and
# module-create no longer ships its own CHANGELOG template.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CANON=skills/magento2-context/references/changelog-format.md
FAIL=0

[ -f "$CANON" ] || { echo "FAIL: canonical $CANON missing"; FAIL=1; }
grep -q 'Keep a Changelog' "$CANON" 2>/dev/null || { echo "FAIL: canonical lacks Keep-a-Changelog structure"; FAIL=1; }

# release cites the canonical rather than redefining the structure.
grep -q 'magento2-context/references/changelog-format.md' skills/magento2-release/references/changelog-format.md \
    || { echo "FAIL: release/changelog-format.md does not cite the canonical"; FAIL=1; }

# module-create no longer ships its own CHANGELOG template.
[ ! -f skills/magento2-module-create/templates/CHANGELOG.md ] \
    || { echo "FAIL: module-create still ships its own CHANGELOG.md template"; FAIL=1; }

exit "$FAIL"
