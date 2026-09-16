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

# A bash-side failure is conclusive on its own — report it rather than downgrading to a
# skip below just because python3 happens to be missing.
[ "$FAIL" -eq 0 ] || exit "$FAIL"

# The bash library and the python emitter must produce identical fingerprints —
# two implementations of one identity is a silent-divergence hazard. The cross-check is
# the whole point of the rest of this file, so a missing python3 is a SKIP, not a PASS.
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH — cannot cross-check the emitter's implementation"
    exit 77
fi

# Cross-check BOTH the plain snippet and the reformatted one. Checking only the plain
# snippet would let the two normalizers diverge on exactly the trailing-separator case
# the fingerprint exists to survive.
for RAW in 'public function execute()' '  public   function execute()  ;'; do
    PY_FP="$(RAW="$RAW" python3 - <<'PY'
import hashlib, os, re
raw = os.environ["RAW"]
snippet = re.sub(r"[,;]*$", "", re.sub(r"\s+", " ", raw).strip()).strip()
parts = ["review", "security", "csrf",
         "POST controller missing form key validation",
         "Controller/Adminhtml/Order/Save.php", snippet]
print(hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest())
PY
)"
    if [ "$A" != "$PY_FP" ]; then
        echo "FAIL: bash ($A) and python ($PY_FP) fingerprints diverge for snippet '$RAW'"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: finding fingerprint is stable, discriminating, and bash==python"
fi
exit "$FAIL"
