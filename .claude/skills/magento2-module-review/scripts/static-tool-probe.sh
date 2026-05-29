#!/usr/bin/env bash
set -euo pipefail

module_path="${1:-}"

if [[ -z "$module_path" || ! -d "$module_path" ]]; then
    echo "Usage: $0 <module-path>" >&2
    exit 2
fi

tool() {
    local name="$1"
    local command="$2"
    if command -v "$name" >/dev/null 2>&1; then
        printf 'AVAILABLE %-18s %s\n' "$name" "$command"
    else
        printf 'MISSING   %-18s %s\n' "$name" "$command"
    fi
}

file_tool() {
    local path="$1"
    local command="$2"
    if [[ -x "$path" || -f "$path" ]]; then
        printf 'AVAILABLE %-18s %s\n' "$path" "$command"
    else
        printf 'MISSING   %-18s %s\n' "$path" "$command"
    fi
}

echo "Static tool probe"
echo "Module path argument: $module_path"
echo ""

tool php "php -l <php-file>"
tool xmllint "xmllint --noout <xml-file>"
tool composer "composer validate <composer-json> --strict"
tool rg "rg -n '<pattern>' $module_path"
tool semgrep "semgrep scan $module_path"

echo ""
echo "Project-local vendor tools"
file_tool vendor/bin/phpcs "vendor/bin/phpcs --standard=Magento2 $module_path"
file_tool vendor/bin/phpmd "vendor/bin/phpmd $module_path text phpmd.xml"
file_tool vendor/bin/phpstan "vendor/bin/phpstan analyse $module_path"
file_tool vendor/bin/psalm "vendor/bin/psalm --show-info=false $module_path"
file_tool vendor/bin/phpunit "vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist $module_path/Test/Unit"
file_tool vendor/bin/rector "vendor/bin/rector process $module_path --dry-run"

echo ""
echo "Optional Magento runtime"
if [[ -f bin/magento ]]; then
    echo "AVAILABLE bin/magento        bin/magento setup:di:compile"
else
    echo "MISSING   bin/magento        Magento CLI runtime checks should be skipped"
fi

