#!/usr/bin/env bash
# test-a11y-scan-templates.sh — false-positive regressions for a11y-audit/scripts/scan-templates.sh.
#
# Every FP class below was hit on real .phtml (multi-line tags, PHP between attributes, labels
# elsewhere in the file, data-role, tabindex="-1" duplicate links, bound/child link text). Each
# rule also has a true-positive control so a fix that silences the rule entirely fails.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

SCAN="$PWD/skills/a11y-audit/scripts/scan-templates.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m2-a11y.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
T="$WORK/mod/view/frontend/templates"
mkdir -p "$T"
PASS=0
FAIL=0

# --- FP 1: <img> whose alt sits lines later, after PHP conditionals ---------------
cat > "$T/fp-img.phtml" <<'EOF'
<a href="/p">
    <img class="card__image"
         src="<?= $escaper->escapeUrl($image) ?>"
         <?php if ($w !== null && $h !== null): ?>
         width="<?= (int) $w ?>"
         height="<?= (int) $h ?>"
         <?php endif; ?>
         alt="<?= $escaper->escapeHtmlAttr($alt) ?>"
         loading="lazy"/>
</a>
<template x-if="r.image"><img :src="r.image"
     :alt="r.title" width="64"></template>
EOF

# --- FP 2: labels elsewhere / wrapping / aria / excluded types / interpolated for-id ---
cat > "$T/fp-label.phtml" <<'EOF'
<form>
    <label for="blog-search" class="label">
        <span><?= $escaper->escapeHtml(__('Search')) ?></span>
    </label>
    <div class="control">
        <p>spacer</p>
        <p>spacer</p>
        <p>spacer</p>
        <p>spacer</p>
        <input id="blog-search"
               type="search" name="q">
    </div>
    <?php foreach ($categories as $category): ?>
        <input type="checkbox" class="checkbox"
               id="muon-contributor-category-<?= (int) $category['id'] ?>"
               name="cat[]" value="<?= (int) $category['id'] ?>"
               <?= $checked ? 'checked' : '' ?>>
        <p>spacer</p>
        <p>spacer</p>
        <p>spacer</p>
        <p>spacer</p>
        <p>spacer</p>
        <label class="label" for="muon-contributor-category-<?= (int) $category['id'] ?>">
            <?= $escaper->escapeHtml($category['label']) ?>
        </label>
    <?php endforeach; ?>
    <label class="choice">
        <span>spacer</span>
        <span>spacer</span>
        <span>spacer</span>
        <span>spacer</span>
        <span>spacer</span>
        <span>spacer</span>
        <input type="checkbox" name="agree">
        <span>I agree</span>
    </label>
    <input type="text" name="a" aria-label="<?= $escaper->escapeHtmlAttr(__('Name')) ?>">
    <input type="text" name="b"
           aria-labelledby="b-heading">
    <input type="text" name="c" :aria-label="label">
    <input type="hidden" name="form_key" value="x">
    <input type="submit" value="Go">
    <input type="button" value="Go">
    <input type="image" src="go.png" alt="Go">
    <textarea id="body"
              name="body"></textarea>
    <p>spacer</p><p>spacer</p><p>spacer</p><p>spacer</p><p>spacer</p>
    <p>spacer</p><p>spacer</p><p>spacer</p><p>spacer</p><p>spacer</p>
    <label for="body">Body</label>
</form>
EOF

# --- FP 3: data-role / bound role are not ARIA roles ------------------------------
cat > "$T/fp-role.html" <<'EOF'
<div class="file-uploader image-uploader" data-role="drop-zone" css="_loading: isLoading"></div>
<div x-bind:role="r" :role="r"></div>
<div role="presentation"></div>
EOF

# --- FP 4: aria-hidden duplicate card link with tabindex="-1" ----------------------
cat > "$T/fp-hidden.phtml" <<'EOF'
<a class="card__media" href="<?= $escaper->escapeUrl($url) ?>" tabindex="-1" aria-hidden="true">
    <img src="x.png" alt="">
</a>
<a class="card__media"
   href="/y"
   tabindex="-1"
   aria-hidden="true"><img src="y.png" alt=""></a>
EOF

# --- FP 5: links with text on later lines / aria / bound text / PHP-string links -----
cat > "$T/fp-link.phtml" <<'EOF'
<?php
/**
 * A doc comment that mentions <a> and <img> tags and an <input>.
 */
$link = '<a href="/z"></a>';
?>
<?= /* @noEscape */ '<a class="' . $class . '" href="' . $href . '">' . $anchor . '</a>' ?>
<a class="w-full block" :href="searchResult.url">
    <div class="grid">
        <div>
            <p>spacer</p>
            <p>spacer</p>
            <p>spacer</p>
            <p>spacer</p>
            <p>spacer</p>
            <span x-text="searchResult.title"></span>
        </div>
    </div>
</a>
<a href="/a"
   class="x">
    <?= $escaper->escapeHtml($title) ?>
</a>
<a href="/b" aria-label="Close"><svg></svg></a>
<a href="/c" data-bind="text: label"></a>
<a href="/d" data-bind="attr: {href: url, 'aria-label': title}"></a>
<a href="/e" x-text="name"></a>
<a href="/f"><span class="sr-only">Next</span><svg></svg></a>
<a href="/g"><img src="g.png" alt="Home"></a>
<button type="button"
        class="action">
    <span><?= $escaper->escapeHtml(__('Add')) ?></span>
</button>
<button type="button" data-bind="click: add, i18n: 'Add'"></button>
EOF

# --- FP 2b: interpolated for/id alone (no bare echo in the tag), bare-echo attrs, KO uid ---
cat > "$T/fp-label2.phtml" <<'EOF'
<input type="checkbox"
       id="cat-<?= (int) $category['id'] ?>" name="c[]">
<p>spacer</p><p>spacer</p>
<p>spacer</p>
<p>spacer</p>
<p>spacer</p>
<p>spacer</p>
<label for="cat-<?= (int) $category['id'] ?>">Cat</label>
<input type="text" <?= $block->getFieldAttributes() ?>>
EOF
cat > "$T/fp-ko.html" <<'EOF'
<label class="admin__field-label" attr="for: uid"><span translate="label"></span></label>
<input type="file" afterRender="onElementRender" attr="id: uid, name: inputName">
<input class="admin__control-text" type="text" data-bind="
    textInput: value,
    attr: {id: uid, 'aria-describedby': noticeId}">
<textarea data-bind="attr: {id: editorId}, value: value"></textarea>
<button type="button" class="action-secondary" data-bind="click: add, i18n: 'Add'"></button>
<label class="file-uploader-button action-default" attr="for: uid" translate="'Upload'"></label>
EOF

# --- True-positive controls: each rule must still fire ---------------------------
cat > "$T/tp.phtml" <<'EOF'
<img src="x">
<input type="text" id="q">
<div role="banana"></div>
<button aria-hidden="true">Hide</button>
<a href="/x"></a>
<button type="button"></button>
<select id="s"><option>1</option></select>
<img
     src="<?= $escaper->escapeUrl($u) ?>"
     <?php if ($x): ?>width="1"<?php endif; ?>
     loading="lazy">
EOF

OUT="$WORK/out.json"
bash "$SCAN" "$WORK/mod" > "$OUT" || { echo "FAIL: scanner exited non-zero"; exit 1; }

# count FILE TITLE-PREFIX [LINE] -> number of matching findings
count() {
    python3 - "$OUT" "$1" "$2" "${3:-}" <<'PY'
import json, sys, os
out, fname, prefix, line = sys.argv[1:5]
n = 0
for f in json.load(open(out)):
    ev = f["evidence"][0]
    if os.path.basename(ev["file"]) == fname and f["title"].startswith(prefix):
        if not line or int(line) == ev["line"]:
            n += 1
print(n)
PY
}

expect() { # expect N FILE TITLE-PREFIX [LINE] -- description
    local want="$1" file="$2" prefix="$3" line="${4:-}" desc="$5" got
    got="$(count "$file" "$prefix" "$line")"
    if [ "$got" = "$want" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $desc — want $want, got $got ($file '$prefix' ${line:+line $line})"
    fi
}

expect 0 fp-img.phtml   "<img> tag missing alt"        "" "multi-line img with alt after PHP conditional / bound :alt"
expect 0 fp-label.phtml "Form input without"           "" "inputs labelled by for/id, wrapping label, aria, excluded types"
expect 0 fp-label.phtml "<textarea> without"           "" "textarea labelled by a later <label for>"
expect 0 fp-role.html   "Invalid or unrecognized ARIA" "" "data-role / bound role are not ARIA roles"
expect 0 fp-hidden.phtml "aria-hidden"                 "" "aria-hidden on tabindex=-1 duplicate link"
expect 0 fp-link.phtml  "<a> tag with no accessible"   "" "links with child/bound/aria text, PHP-string links"
expect 0 fp-link.phtml  "<button> tag with no accessible" "" "buttons with multi-line or i18n text"
expect 0 fp-link.phtml  "Form input without"           "" "tags inside PHP comments are ignored"

expect 0 fp-label2.phtml "Form input without"         "" "interpolated for/id pair; bare-echo attributes"
expect 0 fp-ko.html     "Form input without"           "" "KO element templates bound to uid"
expect 1 fp-ko.html     "<textarea> without"           6  "control: KO-bound id with no matching label still fires"
expect 0 fp-ko.html     "<button> tag with no accessible" "" "KO i18n button text"

expect 2 tp.phtml "<img> tag missing alt"              ""  "control: img with no alt (single + multi-line)"
expect 1 tp.phtml "<img> tag missing alt"              1   "control: img reported at its own line"
expect 1 tp.phtml "<img> tag missing alt"              8   "control: multi-line img reported at tag start"
expect 1 tp.phtml "Form input without associated label" 2 "control: unlabelled text input"
expect 1 tp.phtml "<select> without associated label"   7 "control: unlabelled select"
expect 1 tp.phtml 'Invalid or unrecognized ARIA role: role="banana"' 3 "control: bogus role"
expect 1 tp.phtml "aria-hidden"                        4   "control: aria-hidden on a button"
expect 1 tp.phtml "<a> tag with no accessible text"    5   "control: empty link"
expect 1 tp.phtml "<button> tag with no accessible text" 6 "control: empty button"

echo "a11y scan-templates: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
