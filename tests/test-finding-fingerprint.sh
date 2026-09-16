#!/usr/bin/env bash
# test-finding-fingerprint.sh — contract test for stable finding identity.
#
# finding_fingerprint <producer> <category> <subcategory> <title> <file> <snippet> must:
#   - return the SAME value when only the line number or run date differ (neither is an input);
#   - return the SAME value when the snippet is reformatted (whitespace runs, trailing ,/;);
#   - return a DIFFERENT value when file, title, category or producer differ;
#   - emit 64 lowercase hex chars and nothing else.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LIB="skills/context/scripts/findings-lib.sh"
[ -f "$LIB" ] || { echo "FAIL: $LIB not found"; exit 1; }

# findings-lib.sh is a library; sourcing it must not run a scan.
# shellcheck source=/dev/null
source "$LIB"

if ! declare -F finding_fingerprint >/dev/null; then
    echo "FAIL: finding_fingerprint is not defined by $LIB"
    exit 1
fi

FAIL=0

A="$(finding_fingerprint review security csrf 'POST controller missing form key validation' \
        'Controller/Adminhtml/Order/Save.php' 'public function execute()')"

# Same finding, file edited so the line moved and the snippet was reformatted.
B="$(finding_fingerprint review security csrf 'POST controller missing form key validation' \
        'Controller/Adminhtml/Order/Save.php' '  public   function execute()  ;')"

C="$(finding_fingerprint review security csrf 'POST controller missing form key validation' \
        'Controller/Adminhtml/Order/Delete.php' 'public function execute()')"

D="$(finding_fingerprint review security csrf 'Different title entirely' \
        'Controller/Adminhtml/Order/Save.php' 'public function execute()')"

E="$(finding_fingerprint security security csrf 'POST controller missing form key validation' \
        'Controller/Adminhtml/Order/Save.php' 'public function execute()')"

if [ "$A" != "$B" ]; then
    echo "FAIL: reformatting the snippet changed the fingerprint ($A vs $B)"
    FAIL=1
fi
if [ "$A" = "$C" ]; then echo "FAIL: a different file must change the fingerprint"; FAIL=1; fi
if [ "$A" = "$D" ]; then echo "FAIL: a different title must change the fingerprint"; FAIL=1; fi
if [ "$A" = "$E" ]; then echo "FAIL: a different producer must change the fingerprint"; FAIL=1; fi

if ! printf '%s' "$A" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "FAIL: fingerprint is not 64 lowercase hex chars: '$A'"
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then echo "PASS: finding fingerprint is stable and discriminating"; fi
exit "$FAIL"
