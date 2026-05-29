#!/usr/bin/env bash
# run-all.sh — entry point for the skill-pack contract test suite.
#
# Runs each test script under skills/_tests/ and reports pass/fail counts.
# Exit 0 if every test passes; 1 otherwise.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PASS=0
FAIL=0
FAILED_TESTS=()

for t in test-*.sh; do
    [ -f "$t" ] || continue
    printf "==> %-40s " "$t"
    if bash "$t" >/tmp/test-out.$$ 2>&1; then
        PASS=$((PASS + 1))
        printf "PASS\n"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$t")
        printf "FAIL\n"
        sed 's/^/    /' /tmp/test-out.$$
    fi
    rm -f /tmp/test-out.$$
done

echo
echo "============================================"
echo "  PASS: ${PASS}    FAIL: ${FAIL}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
    exit 1
fi
exit 0
