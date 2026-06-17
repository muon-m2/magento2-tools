#!/usr/bin/env bash
# test-release-notes.sh — scripts/release-notes.sh: version-consistency assert + CHANGELOG extraction.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then echo "skip: python3 not on PATH"; exit 77; fi

H="scripts/release-notes.sh"
FAIL=0

# 1. real repo, current plugin.json version -> non-empty body + title, exit 0
VER="$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
body="$(bash "$H" "$VER")"        || { echo "FAIL: helper non-zero for current version $VER"; FAIL=1; }
[ -n "${body:-}" ]                || { echo "FAIL: empty notes body for $VER"; FAIL=1; }
title="$(bash "$H" --title "$VER")" || { echo "FAIL: --title non-zero for $VER"; FAIL=1; }
[ -n "${title:-}" ]               || { echo "FAIL: empty title for $VER"; FAIL=1; }

# 2. non-existent version -> non-zero
rc=0; bash "$H" 0.0.0-nope >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL: expected non-zero for bogus version"; FAIL=1; }

# 3. fixture: CHANGELOG has [9.9.9] but manifests at 1.0.0 -> exit 3 (version mismatch)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude-plugin"
printf '{\n  "name": "magento2-tools",\n  "version": "1.0.0"\n}\n' > "$tmp/.claude-plugin/plugin.json"
printf '{\n  "plugins": [ { "name": "magento2-tools", "version": "1.0.0" } ]\n}\n' > "$tmp/.claude-plugin/marketplace.json"
printf '# Changelog\n\n## [9.9.9] — test\n\n### Added\n\n- thing\n\n## [1.0.0] — old\n' > "$tmp/CHANGELOG.md"
rc=0; RELEASE_NOTES_ROOT="$tmp" bash "$H" 9.9.9 >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || { echo "FAIL: expected exit 3 (version mismatch) got $rc"; FAIL=1; }

# 4. fixture happy path: manifests at 9.9.9 -> exit 0, body contains 'thing'
sed -i 's/"version": "1.0.0"/"version": "9.9.9"/' "$tmp/.claude-plugin/plugin.json"
sed -i 's/"version": "1.0.0"/"version": "9.9.9"/' "$tmp/.claude-plugin/marketplace.json"
out="$(RELEASE_NOTES_ROOT="$tmp" bash "$H" 9.9.9 2>/dev/null)" || { echo "FAIL: fixture happy path non-zero"; FAIL=1; }
printf '%s' "$out" | grep -q 'thing' || { echo "FAIL: fixture body missing expected content"; FAIL=1; }

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "release-notes: version-assert + changelog extraction verified"
exit 0
