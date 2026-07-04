#!/usr/bin/env bash
# test-feature-implement-docs-root.sh — feature-implement threads --docs-root into its
# sub-skill invocations and documents the nested per-feature layout.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

F=skills/magento2-feature-implement/SKILL.md
FAIL=0

# It must pass --docs-root=.docs/{FeatureName} to sub-skills.
grep -q -- '--docs-root=.docs/{FeatureName}' "$F" \
    || { echo "FAIL: feature-implement does not pass --docs-root=.docs/{FeatureName}"; FAIL=1; }

# It must document the nested category layout (reviews/ tests/ under the feature folder).
grep -q '{FeatureName}/reviews' "$F" \
    || { echo "FAIL: feature-implement does not document the nested category layout"; FAIL=1; }

# It must cite the shared artifact-layout reference.
grep -q 'artifact-layout.md' "$F" \
    || { echo "FAIL: feature-implement does not cite artifact-layout.md"; FAIL=1; }

exit "$FAIL"
