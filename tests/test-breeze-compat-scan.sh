#!/usr/bin/env bash
# test-breeze-compat-scan.sh — false-positive contract for breeze-compat/scripts/static-scan.sh.
#
# Breeze is a storefront theme, so the scanner must:
#   1. ignore view/adminhtml (Breeze never runs in the admin);
#   2. downgrade "requirejs-config present" / "no adapter" to info when a Breeze adapter
#      exists (sibling <module>-breeze package, app/code <Module>Breeze, or self breeze_* assets);
#   3. not flag a Breeze adapter's own Cash `$.widget` (Breeze module or web/js/breeze/);
#   4. keep checkout Knockout at info (Breeze leaves checkout on Luma + Knockout).
# Each class has a true-positive control that must still fire.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

SCAN="$PWD/skills/breeze-compat/scripts/static-scan.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m2-breeze.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0

reg() { # reg <dir> <Module_Name>
    mkdir -p "$1"
    printf "<?php\n\\\\Magento\\\\Framework\\\\Component\\\\ComponentRegistrar::register(\\\\Magento\\\\Framework\\\\Component\\\\ComponentRegistrar::MODULE, '%s', __DIR__);\n" "$2" > "$1/registration.php"
}

# check <label> <scan-target> <python assertion over `f` (list of findings)>
check() {
    local label="$1" target="$2" expr="$3"
    bash "$SCAN" "$target" > "$WORK/out.json"
    if python3 - "$WORK/out.json" "$expr" <<'PY'
import json, sys
f = json.load(open(sys.argv[1]))
def at(sub, cat=None, sev=None):
    return [x for x in f if sub in x['evidence'][0]['file']
            and (cat is None or x['category'] == cat) and (sev is None or x['severity'] == sev)]
ok = eval(sys.argv[2])  # assertion literals written in this file, never external input
if not ok:
    print(json.dumps([(x['severity'], x['category'], x['evidence'][0]['file'], x['title']) for x in f], indent=1))
sys.exit(0 if ok else 1)
PY
    then PASS=$((PASS + 1)); echo "ok: $label"
    else FAIL=$((FAIL + 1)); echo "FAIL: $label"
    fi
}

# --- 1. adminhtml is never scanned; frontend controls still fire ------------------
M="$WORK/vendor/acme/module-admin"
reg "$M" Acme_Admin
mkdir -p "$M/view/adminhtml/web/template" "$M/view/adminhtml/templates" \
         "$M/view/frontend/web/template" "$M/view/frontend/templates"
echo '<div data-bind="text: x"></div>' > "$M/view/adminhtml/web/template/switch.html"
printf "var config = { config: { mixins: { 'x': {'a': true} } }, map: {'*': {c: 'uiComponent'}} };\n" \
    > "$M/view/adminhtml/requirejs-config.js"
echo "<script>require(['jquery'], function () {});</script>" > "$M/view/adminhtml/templates/tree.phtml"
echo "define(['uiComponent'], function (C) {});" > "$M/view/adminhtml/web/x.js"
check "adminhtml produces no findings" "$M" "not at('/adminhtml/')"

echo '<div data-bind="text: x"></div>' > "$M/view/frontend/web/template/foo.html"
echo "<script>require(['jquery'], function () {});</script>" > "$M/view/frontend/templates/inline.phtml"
check "control: frontend data-bind is high knockout" "$M" \
    "at('view/frontend/web/template/foo.html', 'knockout', 'high')"
check "control: frontend inline require([...]) is medium requirejs" "$M" \
    "at('view/frontend/templates/inline.phtml', 'requirejs', 'medium')"

# view/base still counts (shared with the storefront).
mkdir -p "$M/view/base/web/template"
echo '<div data-bind="text: y"></div>' > "$M/view/base/web/template/b.html"
check "control: view/base data-bind still fires" "$M" "at('view/base/web/template/b.html', 'knockout', 'high')"

# --- 2. Breeze adapter detection ---------------------------------------------------
# 2a. composer-layout sibling <pkg>-breeze.
P="$WORK/vendor/acme/module-editor"
reg "$P" Acme_Editor
reg "$P-breeze" Acme_EditorBreeze
mkdir -p "$P/view/frontend/web/js" "$P-breeze/view/frontend/layout"
echo "var config = { paths: { ed: 'Acme_Editor/js/ed' } };" > "$P/view/frontend/requirejs-config.js"
echo "console.log(1);" > "$P/view/frontend/web/js/ed.js"
echo '<page/>' > "$P-breeze/view/frontend/layout/breeze_default.xml"
check "sibling -breeze adapter: requirejs-config downgraded to info naming the adapter" "$P" \
    "at('requirejs-config.js', 'requirejs', 'info') and 'Acme_EditorBreeze' in at('requirejs-config.js')[0]['title'] \
     and not at('requirejs-config.js', 'requirejs', 'medium')"
check "sibling -breeze adapter: assets finding is info naming the adapter" "$P" \
    "[x for x in f if x['category'] == 'assets' and 'Acme_EditorBreeze' in x['title'] and x['severity'] == 'info']"

# 2b. app/code sibling <Module>Breeze.
A="$WORK/app/code/Acme/Gallery"
reg "$A" Acme_Gallery
reg "$WORK/app/code/Acme/GalleryBreeze" Acme_GalleryBreeze
mkdir -p "$A/view/frontend/web/js"
echo "var config = { paths: { g: 'Acme_Gallery/js/g' } };" > "$A/view/frontend/requirejs-config.js"
echo "console.log(1);" > "$A/view/frontend/web/js/g.js"
check "app/code <Module>Breeze adapter: requirejs-config info" "$A" \
    "at('requirejs-config.js', 'requirejs', 'info') and not at('requirejs-config.js', 'requirejs', 'medium')"

# 2c. self-adapter (module ships web/js/breeze/).
S="$WORK/vendor/acme/module-self"
reg "$S" Acme_Self
mkdir -p "$S/view/frontend/web/js/breeze"
echo "var config = { paths: { s: 'Acme_Self/js/s' } };" > "$S/view/frontend/requirejs-config.js"
echo "console.log(1);" > "$S/view/frontend/web/js/breeze/s.js"
check "self web/js/breeze adapter: requirejs-config info, no 'no adapter' finding" "$S" \
    "at('requirejs-config.js', 'requirejs', 'info') and not [x for x in f if x['category'] == 'assets']"

# Controls: no adapter anywhere.
N="$WORK/vendor/acme/module-plain"
reg "$N" Acme_Plain
mkdir -p "$N/view/frontend/web/js"
echo "var config = { config: { mixins: { 'Magento_Catalog/js/x': { 'Acme_Plain/js/x-mixin': true } } } };" \
    > "$N/view/frontend/requirejs-config.js"
echo "console.log(1);" > "$N/view/frontend/web/js/x-mixin.js"
check "control: frontend mixins with no adapter is high mixin" "$N" "at('requirejs-config.js', 'mixin', 'high')"
check "control: no adapter keeps the 'no Breeze adapter' info" "$N" \
    "[x for x in f if x['category'] == 'assets' and 'no Breeze adapter' in x['title']]"
N2="$WORK/vendor/acme/module-plain2"
reg "$N2" Acme_Plain2
mkdir -p "$N2/view/frontend"
echo "var config = { paths: { p: 'Acme_Plain2/js/p' } };" > "$N2/view/frontend/requirejs-config.js"
check "control: requirejs-config with no adapter stays medium" "$N2" "at('requirejs-config.js', 'requirejs', 'medium')"

# --- 3. Breeze adapter's own Cash $.widget ----------------------------------------
B="$P-breeze"
mkdir -p "$B/view/frontend/web/js"
printf "(function () {\n    \$.widget('acmeEditor', { component: 'Acme_Editor/js/ed', create: function () {} });\n})();\n" \
    > "$B/view/frontend/web/js/editor.js"
check "Breeze module \$.widget not flagged" "$B" "not at('editor.js', 'jquery-widget')"
mkdir -p "$S/view/frontend/web/js/breeze"
printf "\$.widget('selfW', { component: 'Acme_Self/js/s', create: function () {} });\n" > "$S/view/frontend/web/js/breeze/w.js"
check "web/js/breeze/ \$.widget not flagged" "$S" "not at('breeze/w.js', 'jquery-widget')"
check "site scan: Breeze module skipped, plain module still scanned" "$WORK/vendor/acme" \
    "not at('module-editor-breeze/') and at('module-plain/view/frontend/requirejs-config.js', 'mixin', 'high')"
mkdir -p "$N/view/frontend/web/js"
printf "define(['jquery', 'jquery-ui-modules/widget'], function (\$) {\n    \$.widget('acme.plain', {});\n});\n" \
    > "$N/view/frontend/web/js/w.js"
check "control: non-Breeze \$.widget still medium jquery-widget" "$N" "at('web/js/w.js', 'jquery-widget', 'medium')"

# --- 4. checkout Knockout is info ---------------------------------------------------
C="$WORK/vendor/acme/module-pay"
reg "$C" Acme_Pay
mkdir -p "$C/view/frontend/web/template/checkout" "$C/view/frontend/web/js/view" "$C/view/frontend/layout"
echo '<div data-bind="text: x"></div>' > "$C/view/frontend/web/template/checkout/summary.html"
echo "define(['uiComponent'], function (C) {});" > "$C/view/frontend/web/js/view/pay.js"
echo '<div data-bind="text: y"></div>' > "$C/view/frontend/web/template/pay-form.html"
cat > "$C/view/frontend/layout/checkout_index_index.xml" <<'XML'
<page><body><referenceBlock name="checkout.root"><arguments><argument name="jsLayout" xsi:type="array">
  <item name="pay" xsi:type="array">
    <item name="component" xsi:type="string">Acme_Pay/js/view/pay</item>
    <item name="config" xsi:type="array"><item name="template" xsi:type="string">Acme_Pay/pay-form</item></item>
  </item>
</argument></arguments></referenceBlock></body></page>
XML
echo '<div data-bind="text: z"></div>' > "$C/view/frontend/web/template/widget.html"
check "checkout template/checkout/** knockout is info" "$C" \
    "at('template/checkout/summary.html', 'knockout', 'info') and not at('template/checkout/summary.html', 'knockout', 'high')"
check "checkout_index_index component + template knockout is info" "$C" \
    "at('js/view/pay.js', 'knockout', 'info') and at('template/pay-form.html', 'knockout', 'info') \
     and not at('js/view/pay.js', 'knockout', 'high') and not at('template/pay-form.html', 'knockout', 'high')"
check "control: non-checkout template in same module stays high" "$C" "at('template/widget.html', 'knockout', 'high')"

echo "breeze-compat-scan: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
