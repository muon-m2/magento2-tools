#!/usr/bin/env bash
# feature-implement Phase 7A HTML guides link into the module Markdown docs rather than
# duplicating them.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
F=skills/magento2-feature-implement/references/documentation-guide.md
FAIL=0
grep -qiE 'cross-link|link (to|into) the (per-)?module' "$F" \
    || { echo "FAIL: documentation-guide does not state the HTML tier links into module docs"; FAIL=1; }
grep -qi 'do not (re-author|duplicate)' "$F" \
    || { echo "FAIL: documentation-guide does not state the no-duplication rule"; FAIL=1; }
exit "$FAIL"
