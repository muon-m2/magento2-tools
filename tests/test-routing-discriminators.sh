#!/usr/bin/env bash
# test-routing-discriminators.sh — pin the routing disambiguation. Each disambiguated skill's
# `description` frontmatter must reference the sibling skill(s) it defers to, so a future reword
# can't silently drop a routing guard. Scoped to the description block (not the whole file).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0

# Print only the YAML `description:` block of a SKILL.md (the 'description:' line plus its
# indented continuation lines, up to the next top-level key or the closing '---').
desc() { # skill-name
    awk '
        NR==1 && $0=="---" { infm=1; next }
        infm && $0=="---" { exit }
        infm && /^description:/ { indesc=1; print; next }
        infm && indesc && /^[A-Za-z_-]+:/ { indesc=0 }
        infm && indesc { print }
    ' "skills/magento2-$1/SKILL.md"
}

check() { # skill ref...
    local skill="$1"; shift
    local d ref
    d="$(desc "$skill")"
    if [ -z "$d" ]; then
        echo "FAIL: magento2-$skill — could not extract description frontmatter"; FAIL=1; return
    fi
    for ref in "$@"; do
        printf '%s' "$d" | grep -qF "$ref" \
            || { echo "FAIL: magento2-$skill description must reference '$ref'"; FAIL=1; }
    done
}

check cli-command         magento2-module-create
check message-queue       magento2-module-create
check feature-implement   magento2-adminhtml-form magento2-graphql-create magento2-eav-attribute
check system-config       magento2-module-create magento2-adminhtml-form
check module-create       magento2-adminhtml-form magento2-graphql-create magento2-eav-attribute
check extension-point     magento2-module-create magento2-feature-implement
check module-review       magento2-security-audit magento2-performance-audit
check security-audit      magento2-module-review
check debug               magento2-performance-audit
check performance-audit   magento2-debug
check eav-attribute       magento2-data-migration
check data-migration      magento2-eav-attribute
check static-analysis     magento2-module-review
check indexer             magento2-module-create magento2-performance-audit
check marketplace-prep    magento2-security-audit magento2-release
check accessibility-audit magento2-frontend-create magento2-module-review
check breeze-child-theme   magento2-frontend-create
check breeze-module-adapt  magento2-extension-point magento2-breeze-compat-audit
check breeze-compat-audit  magento2-module-review magento2-breeze-module-adapt
check audit                magento2-module-review magento2-security-audit magento2-performance-audit magento2-feature-implement

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "routing discriminators: all cross-references present"
exit 0
