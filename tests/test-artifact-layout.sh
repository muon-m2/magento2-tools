#!/usr/bin/env bash
# test-artifact-layout.sh — the shared artifact-layout reference exists and enumerates
# every artifact category, and findings-schema File Naming cites the unified scheme.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
LAYOUT=skills/magento2-context/references/artifact-layout.md

if [ ! -f "$LAYOUT" ]; then
    echo "FAIL: $LAYOUT missing"; exit 1
fi

# Every known category directory must be registered in the layout reference.
for cat in reviews audits quality marketplace accessibility breeze-compat upgrades \
           tests docs-generated deployments releases i18n bug-fixes debug \
           adminhtml-forms adminhtml-listings cli-commands eav-attributes \
           extension-points indexers message-queues system-config migrations; do
    if ! grep -q "$cat" "$LAYOUT"; then
        echo "FAIL: category '$cat' not registered in artifact-layout.md"; FAIL=1
    fi
done

# The unified scheme + the DOCS_ROOT recipe must be documented.
grep -q 'DOCS_ROOT' "$LAYOUT" || { echo "FAIL: artifact-layout.md does not document DOCS_ROOT"; FAIL=1; }
grep -q -- '--docs-root' "$LAYOUT" || { echo "FAIL: artifact-layout.md does not document --docs-root"; FAIL=1; }

# findings-schema File Naming must no longer hardcode the old scope-word audit names.
SCHEMA=skills/magento2-context/references/findings-schema.md
grep -q 'artifact-layout.md' "$SCHEMA" || { echo "FAIL: findings-schema.md does not cite artifact-layout.md"; FAIL=1; }

exit "$FAIL"
