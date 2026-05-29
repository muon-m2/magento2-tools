#!/usr/bin/env bash
set -euo pipefail

module_path="${1:-}"

if [[ -z "$module_path" || ! -d "$module_path" ]]; then
    echo "Usage: $0 <module-path>" >&2
    exit 2
fi

echo ""
echo "== PHP parse check =="
if command -v php >/dev/null 2>&1; then
    find "$module_path" -type f -name '*.php' -print0 | xargs -0 php -l 2>&1 | grep -v "^No syntax errors" || true
else
    echo "SKIPPED php lint: php not found"
fi

# Search PHP files only.
search_php() {
    local title="$1"
    local pattern="$2"
    echo ""
    echo "== $title =="
    if command -v rg >/dev/null 2>&1; then
        rg -n -t php "$pattern" "$module_path" || true
    else
        grep -RInE --include='*.php' "$pattern" "$module_path" || true
    fi
}

# Search XML files only.
search_xml() {
    local title="$1"
    local pattern="$2"
    echo ""
    echo "== $title =="
    if command -v rg >/dev/null 2>&1; then
        rg -n -t xml "$pattern" "$module_path" || true
    else
        grep -RInE --include='*.xml' "$pattern" "$module_path" || true
    fi
}

# Search all text files.
search_all() {
    local title="$1"
    local pattern="$2"
    echo ""
    echo "== $title =="
    if command -v rg >/dev/null 2>&1; then
        rg -n "$pattern" "$module_path" || true
    else
        grep -RInE "$pattern" "$module_path" || true
    fi
}

search_php "Risk patterns" "ObjectManager::getInstance|die\(|exit\(|var_dump|print_r|eval\(|unserialize\(|base64_decode\(|shell_exec\(|exec\(|passthru\("
search_all "Suppressions and TODOs" "TODO|FIXME|@codingStandardsIgnore|phpcs:disable|SuppressWarnings"
# XML element names only — file-presence detection is handled by discover-module.sh.
search_xml "Magento DI and event surfaces" "<(preference|plugin|observer|event|route|job|virtualType)"
search_php "Input and request access" "getParam\(|getPost\(|getQuery\(|\\\$_GET|\\\$_POST|\\\$_REQUEST|\\\$_FILES"
search_php "Output and escaping" "escapeHtml|escapeHtmlAttr|escapeUrl|escapeJs"
search_php "PHPDoc tags" "@param|@return|@throws|@api|@internal|@deprecated"

