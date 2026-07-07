#!/usr/bin/env bash
# test-source-of-truth-rollout.sh — every in-scope generator SKILL.md must carry the
# **Source of truth.** Core Rule bullet and a Reference-Files pointer to the shared reference.
# Out-of-scope read-only/audit skills must NOT carry it.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

IN_SCOPE=(
  magento2-module-create magento2-frontend-create magento2-graphql-create magento2-webapi-create
  magento2-adminhtml-form magento2-adminhtml-listing magento2-extension-point magento2-system-config
  magento2-cli-command magento2-eav-attribute magento2-message-queue magento2-data-migration
  magento2-indexer magento2-breeze-child-theme magento2-breeze-module-adapt
  magento2-docs-generate magento2-test-generate magento2-feature-implement
)
OUT_OF_SCOPE=(
  magento2-module-review magento2-security-audit magento2-performance-audit
  magento2-accessibility-audit magento2-breeze-compat-audit magento2-static-analysis
  magento2-audit magento2-marketplace-prep magento2-debug
)
FAIL=0

for s in "${IN_SCOPE[@]}"; do
    f="skills/$s/SKILL.md"
    [ -f "$f" ] || { echo "FAIL: $f not found"; FAIL=1; continue; }
    grep -qE '^\s*-\s*\*\*Source of truth\.\*\*' "$f" \
        || { echo "FAIL: $f missing **Source of truth.** Core Rule bullet"; FAIL=1; }
    grep -qE '^\s*-\s*`magento2-context/references/source-of-truth\.md`' "$f" \
        || { echo "FAIL: $f missing source-of-truth.md reference pointer"; FAIL=1; }
done

for s in "${OUT_OF_SCOPE[@]}"; do
    f="skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    grep -qF 'source-of-truth.md' "$f" \
        && { echo "FAIL: $f (read-only/audit) must NOT reference source-of-truth.md"; FAIL=1; }
done

[ "$FAIL" -eq 0 ] && echo "PASS: all 18 generators carry the rule; audit skills untouched"
exit "$FAIL"
