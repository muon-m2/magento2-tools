#!/usr/bin/env bash
# Verify a generated adminhtml form: XML well-formedness (xmllint) of the form / layout / di / acl /
# menu / routes files, and `php -l` of the controllers, DataProvider, button blocks, and modifier.
#
# Usage: verify-form.sh <module_root> [Entity]
#   <module_root>  e.g. src/app/code/Acme/Faq
# Scans every file and exits non-zero if any are invalid (it does not stop at the first).
# Tools that are absent are skipped with a notice.
set -uo pipefail

MODULE_ROOT="${1:?usage: verify-form.sh <module_root> [Entity]}"
ENTITY="${2:-}"
fail=0

if command -v xmllint >/dev/null 2>&1; then
    while IFS= read -r xml; do
        if ! xmllint --noout "$xml" 2>/tmp/xmllint.err; then
            echo "XML INVALID: $xml"
            sed 's/^/    /' /tmp/xmllint.err
            fail=1
        fi
    done < <(find "$MODULE_ROOT" \
        \( -path '*/view/adminhtml/ui_component/*_form.xml' \
           -o -path '*/view/adminhtml/layout/*_edit.xml' \
           -o -path '*/etc/adminhtml/*.xml' \
           -o -path '*/etc/acl.xml' \) -type f 2>/dev/null)
else
    echo "skip: xmllint not on PATH"
fi

if command -v php >/dev/null 2>&1; then
    while IFS= read -r php_file; do
        out="$(php -l "$php_file" 2>&1)"
        if ! printf '%s' "$out" | grep -q 'No syntax errors detected'; then
            echo "PHP INVALID: $php_file"
            printf '%s\n' "$out" | sed 's/^/    /'
            fail=1
        fi
    done < <(find "$MODULE_ROOT" \
        \( -path '*/Controller/Adminhtml/*' \
           -o -path '*/Model/*/DataProvider.php' \
           -o -path '*/Block/Adminhtml/*/Edit/*Button.php' \
           -o -path '*/Ui/*/Form/Modifier/*.php' \) -name '*.php' -type f 2>/dev/null)
else
    echo "skip: php not on PATH"
fi

if [ "$fail" -eq 0 ]; then
    echo "OK: form XML well-formed and PHP lints clean${ENTITY:+ ($ENTITY)}"
fi
exit "$fail"
