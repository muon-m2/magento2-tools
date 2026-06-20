#!/usr/bin/env bash
# test-license-header-coverage.sh — Tier 2 cross-cutting guard.
#
# Every skill that ships at least one `templates/*.php` file writes PHP into a module/theme and
# therefore MUST wire in the shared copyright-header stamper. Its SKILL.md must reference either
# `add-license-headers.sh` (the action) or `module-hygiene` (the shared contract that mandates it).
#
# This makes the hygiene baseline self-enforcing: adding a new PHP-generating skill, or forgetting to
# wire an existing one, fails this test.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

missing=()
checked=0

for skill_dir in skills/*/; do
    skill="$(basename "$skill_dir")"
    # Only skills that actually emit PHP into a target module/theme.
    if ! find "${skill_dir}templates" -name '*.php' -type f 2>/dev/null | grep -q .; then
        continue
    fi
    checked=$((checked + 1))
    sk="${skill_dir}SKILL.md"
    if [ ! -f "$sk" ]; then
        missing+=("$skill (no SKILL.md)")
        continue
    fi
    if ! grep -qE 'add-license-headers\.sh|module-hygiene' "$sk"; then
        missing+=("$skill")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "FAIL: these PHP-generating skills do not wire in the shared header stamper"
    echo "      (SKILL.md must reference add-license-headers.sh or module-hygiene):"
    for m in "${missing[@]}"; do echo "  - $m"; done
    exit 1
fi

echo "license-header coverage: all $checked PHP-generating skills wire in the shared stamper"
exit 0
