#!/usr/bin/env bash
# test-source-of-truth-reference.sh — the shared source-of-truth reference must exist and
# codify the hierarchy, the no-scan rule, the allowed-reads exceptions, the doc allowlist,
# and the report-affirmation line.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

REF="skills/magento2-context/references/source-of-truth.md"
FAIL=0

if [ ! -f "$REF" ]; then
    echo "FAIL: $REF not found"
    exit 1
fi

require() {
    # require <grep-flags> <pattern> <human description>
    grep -q "$1" "$2" "$REF" 2>/dev/null || { echo "FAIL: $REF missing $3"; FAIL=1; }
}
require -iF "Source-of-Truth"        "source-of-truth hierarchy heading"
require -F  "developer.adobe.com"    "Adobe Commerce docs allowlist host"
require -F  "devdocs.magento.com"    "DevDocs allowlist host"
require -iF "Allowed reads"          "allowed-reads (exceptions) section"
require -iF "is banned"      "the no-scan prohibition"
require -F  "Sources:"               "the report-affirmation line"

[ "$FAIL" -eq 0 ] && echo "PASS: source-of-truth reference is complete"
exit "$FAIL"
