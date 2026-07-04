#!/usr/bin/env bash
# Each single-surface generator tells the user to refresh docs after it mutates a module.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SKILLS=(
    magento2-webapi-create magento2-graphql-create magento2-frontend-create
    magento2-adminhtml-form magento2-adminhtml-listing magento2-cli-command
    magento2-eav-attribute magento2-extension-point magento2-system-config
    magento2-message-queue magento2-indexer magento2-data-migration
)
FAIL=0
for s in "${SKILLS[@]}"; do
    f="skills/${s}/SKILL.md"
    grep -q 'Docs may now be stale' "$f" \
        || { echo "FAIL: ${s}/SKILL.md missing the 'Docs may now be stale' callout"; FAIL=1; }
    grep -q 'magento2-docs-generate --module=' "$f" \
        || { echo "FAIL: ${s}/SKILL.md missing 'magento2-docs-generate --module=' command"; FAIL=1; }
done
exit "$FAIL"
