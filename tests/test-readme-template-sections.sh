#!/usr/bin/env bash
# The single README template carries the richer sections consolidated from module-create,
# and every token it uses is registered in placeholder-schema.md.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

T=skills/magento2-docs-generate/templates/readme.md
SCHEMA=skills/magento2-context/references/placeholder-schema.md
FAIL=0

for section in "## Features" "## Configuration" "## Public API" "## Known Limitations"; do
    grep -qF "$section" "$T" || { echo "FAIL: README template missing '$section'"; FAIL=1; }
done

# Every {TOKEN} used in the template must be registered in the schema.
while IFS= read -r tok; do
    grep -qF "$tok" "$SCHEMA" || { echo "FAIL: token $tok not registered in placeholder-schema.md"; FAIL=1; }
done < <(grep -oE '\{[A-Z_]+\}' "$T" | sort -u)

exit "$FAIL"
