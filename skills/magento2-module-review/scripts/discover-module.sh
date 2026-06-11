#!/usr/bin/env bash
set -euo pipefail

module_path="${1:-}"

if [[ -z "$module_path" || ! -d "$module_path" ]]; then
    echo "Usage: $0 <module-path>" >&2
    exit 2
fi

echo "Module path: $module_path"
echo ""

echo "== Key files =="
for file in \
    registration.php composer.json \
    etc/module.xml etc/di.xml \
    etc/db_schema.xml etc/db_schema_whitelist.json \
    etc/webapi.xml etc/schema.graphqls \
    etc/acl.xml etc/config.xml \
    etc/adminhtml/system.xml \
    etc/frontend/routes.xml etc/adminhtml/routes.xml \
    etc/crontab.xml etc/queue_consumer.xml \
    etc/csp_whitelist.xml; do
    if [[ -f "$module_path/$file" ]]; then
        echo "FOUND $file"
    fi
done

echo ""
echo "== Surface directories =="
for dir in \
    "view/frontend/layout" "view/adminhtml/layout" \
    "view/frontend/templates" "view/adminhtml/templates" \
    "view/frontend/email" \
    "i18n" \
    "Setup/Patch/Data" "Setup/Patch/Schema" \
    "Test/Unit" "Test/Integration"; do
    if [[ -d "$module_path/$dir" ]]; then
        count=$(find "$module_path/$dir" -type f | wc -l)
        echo "FOUND $dir ($count files)"
    fi
done

echo ""
echo "== File counts =="
find "$module_path" -type f | wc -l | awk '{print "files: " $1}'
find "$module_path" -type f -name '*.php' | wc -l | awk '{print "php: " $1}'
find "$module_path" -type f -name '*.xml' | wc -l | awk '{print "xml: " $1}'
find "$module_path" -type f -name '*.phtml' | wc -l | awk '{print "phtml: " $1}'
find "$module_path" -type f \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.less' \) | wc -l | awk '{print "frontend assets: " $1}'

echo ""
echo "== PHP classes/interfaces =="
# Match class/interface/trait/enum declarations including leading modifiers such
# as `final`, `abstract`, and `readonly` (PHP 8.2+), in any order.
class_re='^[[:space:]]*((final|abstract|readonly)[[:space:]]+)*(class|interface|trait|enum)[[:space:]]'
if command -v rg >/dev/null 2>&1; then
    rg -n "$class_re" "$module_path" || true
else
    grep -RInE "$class_re" "$module_path" || true
fi

echo ""
echo "== Magento XML surfaces =="
if command -v rg >/dev/null 2>&1; then
    rg -n "<(preference|plugin|observer|event|route|job|field|table|constraint|index|type|virtualType)" "$module_path/etc" "$module_path/view" 2>/dev/null || true
else
    grep -RInE "<(preference|plugin|observer|event|route|job|field|table|constraint|index|type|virtualType)" "$module_path/etc" "$module_path/view" 2>/dev/null || true
fi

