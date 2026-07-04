#!/usr/bin/env bash
# test-docs-root-threading.sh — every artifact-producing skill documents the
# --docs-root output-root override in its SKILL.md.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Task 3 covers the 9 script-backed emitters; Task 4 extends this array to the
# remaining 15 LLM-report skills.
SKILLS=(
    magento2-module-review magento2-security-audit magento2-performance-audit
    magento2-static-analysis magento2-marketplace-prep magento2-accessibility-audit
    magento2-breeze-compat-audit magento2-module-upgrade magento2-deploy
    magento2-test-generate magento2-docs-generate magento2-release magento2-i18n
    magento2-debug magento2-bug-fix magento2-adminhtml-form magento2-adminhtml-listing
    magento2-cli-command magento2-eav-attribute magento2-extension-point
    magento2-indexer magento2-message-queue magento2-system-config magento2-data-migration
)

FAIL=0
for s in "${SKILLS[@]}"; do
    f="skills/${s}/SKILL.md"
    if [ ! -f "$f" ]; then echo "FAIL: $f missing"; FAIL=1; continue; fi
    if ! grep -q -- '--docs-root' "$f"; then
        echo "FAIL: ${s}/SKILL.md does not document --docs-root"; FAIL=1
    fi
done
exit "$FAIL"
