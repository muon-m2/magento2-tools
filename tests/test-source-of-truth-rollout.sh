#!/usr/bin/env bash
# test-source-of-truth-rollout.sh — every in-scope generator SKILL.md must carry the
# **Source of truth.** Core Rule bullet and a Reference-Files pointer to the shared reference.
# Out-of-scope read-only/audit skills must NOT carry it.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

IN_SCOPE=(
  module-create frontend graphql webapi
  admin-form admin-listing extension-point system-config
  cli-command eav-attribute message-queue data-migration
  indexer breeze-theme breeze-adapt widget
  docs test-generate feature
)
OUT_OF_SCOPE=(
  review security perf-audit
  a11y-audit breeze-compat lint
  audit marketplace debug
  triage
)
FAIL=0

for s in "${IN_SCOPE[@]}"; do
    f="skills/$s/SKILL.md"
    [ -f "$f" ] || { echo "FAIL: $f not found"; FAIL=1; continue; }
    grep -qE '^[[:space:]]*-[[:space:]]*\*\*Source of truth\.\*\*' "$f" \
        || { echo "FAIL: $f missing **Source of truth.** Core Rule bullet"; FAIL=1; }
    grep -qE '^[[:space:]]*-[[:space:]]*`context/references/source-of-truth\.md`' "$f" \
        || { echo "FAIL: $f missing source-of-truth.md reference pointer"; FAIL=1; }
done

for s in "${OUT_OF_SCOPE[@]}"; do
    f="skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    grep -qF 'source-of-truth.md' "$f" \
        && { echo "FAIL: $f (read-only/audit) must NOT reference source-of-truth.md"; FAIL=1; }
done

[ "$FAIL" -eq 0 ] && echo "PASS: all ${#IN_SCOPE[@]} generators carry the rule; audit skills untouched"
exit "$FAIL"
