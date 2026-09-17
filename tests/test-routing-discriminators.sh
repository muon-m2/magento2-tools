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
    ' "skills/$1/SKILL.md"
}

check() { # skill ref...
    local skill="$1"; shift
    local d ref
    d="$(desc "$skill")"
    if [ -z "$d" ]; then
        echo "FAIL: $skill — could not extract description frontmatter"; FAIL=1; return
    fi
    for ref in "$@"; do
        printf '%s' "$d" | grep -qF "$ref" \
            || { echo "FAIL: $skill description must reference '$ref'"; FAIL=1; }
    done
}

check cli-command magento2-tools:module-create
check message-queue magento2-tools:module-create
check feature magento2-tools:admin-form magento2-tools:graphql magento2-tools:eav-attribute
check system-config magento2-tools:module-create magento2-tools:admin-form
check module-create magento2-tools:admin-form magento2-tools:graphql magento2-tools:eav-attribute
check extension-point magento2-tools:module-create magento2-tools:feature
check review magento2-tools:security magento2-tools:perf-audit
check security magento2-tools:review
check debug magento2-tools:perf-audit
check perf-audit magento2-tools:debug
check eav-attribute magento2-tools:data-migration
check data-migration magento2-tools:eav-attribute
check lint magento2-tools:review
check indexer magento2-tools:module-create magento2-tools:perf-audit
check marketplace magento2-tools:security magento2-tools:release
check a11y-audit magento2-tools:frontend magento2-tools:review
check frontend magento2-tools:breeze-theme magento2-tools:breeze-adapt magento2-tools:widget
check widget magento2-tools:module-create magento2-tools:frontend magento2-tools:breeze-adapt
check breeze-theme magento2-tools:frontend
check breeze-adapt magento2-tools:extension-point magento2-tools:breeze-compat
check breeze-compat magento2-tools:review magento2-tools:breeze-adapt
check audit magento2-tools:review magento2-tools:security magento2-tools:perf-audit magento2-tools:feature
check triage magento2-tools:audit magento2-tools:remediate magento2-tools:review magento2-tools:fix
check remediate magento2-tools:triage magento2-tools:audit magento2-tools:fix magento2-tools:feature

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "routing discriminators: all cross-references present"
exit 0
