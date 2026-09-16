#!/usr/bin/env bash
# test-triage-waivers.sh — contract test for waiver suppression state.
#
# waivers-lib.sh must:
#   - suppress a finding whose fingerprint matches an unexpired waiver;
#   - RESURFACE a finding whose waiver has expired (never keep suppressing);
#   - report a waiver whose fingerprint matches nothing as stale;
#   - warn when the waivers file is gitignored or untracked, because .docs suppressions
#     that are not committed reset silently;
#   - never treat a waived finding as closed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LIB="skills/context/scripts/waivers-lib.sh"
[ -f "$LIB" ] || { echo "FAIL: $LIB not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

work="$(mktemp -d "${TMPDIR:-/tmp}/m2-waivers.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cat > "$work/waivers.yml" <<'YAML'
version: 1
waivers:
  - fingerprint: "aaaa1111"
    finding: "security/csrf: POST controller missing form key validation"
    file: Controller/Adminhtml/Order/Save.php
    verdict: false-positive
    reason: "Validated by the parent Action; see ADR-14"
    author: s.autushka
  - fingerprint: "bbbb2222"
    finding: "review/style: line too long"
    file: Model/Foo.php
    verdict: accepted-risk
    reason: "Generated file"
    author: s.autushka
    expires: 2020-01-01
  - fingerprint: "cccc3333"
    finding: "a finding that no longer exists"
    file: Model/Gone.php
    verdict: wont-fix
    reason: "Module removed"
    author: s.autushka
YAML

# shellcheck source=/dev/null
source "$LIB"
waivers_load "$work/waivers.yml"

FAIL=0

S="$(waivers_status aaaa1111 2026-09-16)"
[ "$S" = "active" ] || { echo "FAIL: unexpired waiver → '$S', expected 'active'"; FAIL=1; }

S="$(waivers_status bbbb2222 2026-09-16)"
[ "$S" = "expired" ] || { echo "FAIL: waiver with expires=2020-01-01 → '$S', expected 'expired'"; FAIL=1; }

S="$(waivers_status dddd4444 2026-09-16)"
[ "$S" = "none" ] || { echo "FAIL: unknown fingerprint → '$S', expected 'none'"; FAIL=1; }

[ "${WAIVER_REASON[aaaa1111]}" = "Validated by the parent Action; see ADR-14" ] \
    || { echo "FAIL: reason not carried through"; FAIL=1; }
[ "${WAIVER_AUTHOR[aaaa1111]}" = "s.autushka" ] \
    || { echo "FAIL: author not carried through"; FAIL=1; }

# cccc3333 is waived but matches no current finding → stale.
STALE="$(waivers_stale aaaa1111 bbbb2222)"
if ! printf '%s' "$STALE" | grep -q cccc3333; then
    echo "FAIL: waiver matching no finding was not reported stale (got '$STALE')"
    FAIL=1
fi
if printf '%s' "$STALE" | grep -q aaaa1111; then
    echo "FAIL: a matched waiver was wrongly reported stale"
    FAIL=1
fi

# Gitignored waivers file must warn (on stderr) but not fail.
git -C "$work" init -q 2>/dev/null
echo ".docs/" > "$work/.gitignore"
mkdir -p "$work/.docs/findings"
cp "$work/waivers.yml" "$work/.docs/findings/waivers.yml"
WARN="$( cd "$work" && waivers_check_ignored .docs/findings/waivers.yml 2>&1 >/dev/null )"
RC=$?
[ "$RC" -eq 0 ] || { echo "FAIL: waivers_check_ignored exited $RC, expected 0"; FAIL=1; }
if [ -z "$WARN" ]; then
    echo "FAIL: gitignored waivers file produced no warning — suppressions would reset silently"
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then echo "PASS: waiver suppression, expiry, staleness and the ignore warning"; fi
exit "$FAIL"
