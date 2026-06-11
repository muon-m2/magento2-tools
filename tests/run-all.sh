#!/usr/bin/env bash
# run-all.sh — entry point for the skill-pack contract test suite.
#
# Runs each test-*.sh script in this directory and reports pass/fail/skip counts.
# A test exits 0 to PASS, 77 to SKIP (missing interpreter/tool), anything else to FAIL.
# Exit 0 if no test failed (skips are allowed); 1 otherwise.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PASS=0
FAIL=0
SKIP=0
FAILED_TESTS=()
SKIPPED_TESTS=()

OUT_FILE="$(mktemp "${TMPDIR:-/tmp}/m2-test-out.XXXXXX")"
trap 'rm -f "$OUT_FILE"' EXIT

for t in test-*.sh; do
    [ -f "$t" ] || continue
    printf "==> %-40s " "$t"
    rc=0
    bash "$t" >"$OUT_FILE" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS + 1))
        printf "PASS\n"
    elif [ "$rc" -eq 77 ]; then
        SKIP=$((SKIP + 1))
        SKIPPED_TESTS+=("$t")
        printf "SKIP\n"
        sed 's/^/    /' "$OUT_FILE"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$t")
        printf "FAIL\n"
        sed 's/^/    /' "$OUT_FILE"
    fi
done

echo
echo "============================================"
echo "  PASS: ${PASS}    FAIL: ${FAIL}    SKIP: ${SKIP}"
echo "============================================"

if [ "$SKIP" -gt 0 ]; then
    echo "Skipped tests:"
    for t in "${SKIPPED_TESTS[@]}"; do echo "  - $t"; done
fi

if [ "$FAIL" -gt 0 ]; then
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
    exit 1
fi
exit 0
