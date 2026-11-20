#!/usr/bin/env bash
# scan-templates.sh — read-only STATIC accessibility scan of storefront templates.
#
# Scans .phtml/.html templates and .less/.css files under TARGET_PATH for WCAG 2.1
# Level AA issues, outputting a JSON array of finding objects conforming to
# context/references/findings-schema.md.
#
# See references/wcag-rules.md for the full check catalog.
# See references/theme-discovery.md for template location rules.
#
# Inputs (env vars or positional):
#   TARGET_PATH       Path to the module root or theme root (required, or $1)
#   TARGET_MODULE     Module name, e.g. "Acme_Storefront" (default: derived from module.xml)
#   THEME             Active frontend theme, e.g. "hyva" or "Magento/luma" (default: "")
#   EXTRA_SCAN_ROOTS  optional: os.pathsep- or newline-separated list of additional roots
#                     to scan (e.g. caller-resolved theme-override directories under
#                     app/design/frontend/...; see references/theme-discovery.md)
#
# Output:
#   JSON array of finding objects written to stdout.
#   Never installs anything, never modifies files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PATH="${TARGET_PATH:-${1:-}}"
: "${TARGET_PATH:?TARGET_PATH is required (pass as env var or \$1)}"

TARGET_MODULE="${TARGET_MODULE:-}"
THEME="${THEME:-}"
EXTRA_SCAN_ROOTS="${EXTRA_SCAN_ROOTS:-}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 0
fi

# ---------------------------------------------------------------------------
# Derive module name from etc/module.xml if not provided.
# ---------------------------------------------------------------------------
if [ -z "$TARGET_MODULE" ] && [ -f "${TARGET_PATH}/etc/module.xml" ]; then
    TARGET_MODULE="$(grep -oE 'name="[^"]+"' "${TARGET_PATH}/etc/module.xml" | head -1 | sed 's/name="//;s/"//' || true)"
fi
TARGET_MODULE="${TARGET_MODULE:-unknown_module}"

# ---------------------------------------------------------------------------
# Run all checks via Python (keeps JSON generation clean and robust).
# ---------------------------------------------------------------------------
TARGET_PATH="$TARGET_PATH" \
TARGET_MODULE="$TARGET_MODULE" \
THEME="$THEME" \
EXTRA_SCAN_ROOTS="$EXTRA_SCAN_ROOTS" \
python3 <<'PY'
import bisect
import json
import os
import re
import sys

target_path = os.environ.get("TARGET_PATH", "").rstrip("/")
target_module = os.environ.get("TARGET_MODULE", "unknown_module")
theme = os.environ.get("THEME", "").lower()

is_hyva = "hyva" in theme

findings = []
seq = 1

SKIP_DIRS = {"vendor", "generated", "var", ".git", "node_modules", "Test", "test"}

ROOT_LAYOUT_PATTERNS = re.compile(
    r'(root\.phtml|1column\.phtml|2columns-left\.phtml|2columns-right\.phtml'
    r'|3columns\.phtml|empty\.phtml|page-layout-[^/]+\.phtml)$'
)


# `category` carries the documented top-level bucket for this skill
# (alt-text / aria / semantic-html / keyboard / contrast / forms — see
# context/references/findings-schema.md), so byCategory summarization groups
# by the real bucket rather than lumping everything under a single "accessibility" key.
def finding(severity, title, file_path, line, recommendation,
            verification, category="accessibility", tags=None, extra_evidence=None):
    global seq
    evidence = [{"file": file_path, "line": line}]
    for extra in extra_evidence or []:
        evidence.append({"file": extra, "line": 1})
    f = {
        "id": f"a11y-{seq:04d}",
        "severity": severity,
        "category": category,
        "title": title,
        "evidence": evidence,
        "recommendation": recommendation,
        "verification": verification,
        "tags": tags or ["wcag", "accessibility"],
    }
    findings.append(f)
    seq += 1


def walk_files(root, extensions):
    """Walk root, skipping skip dirs, yielding (filepath, ext)."""
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in extensions:
                yield os.path.join(dirpath, fname), ext


def read_lines(fpath):
    try:
        with open(fpath, encoding="utf-8", errors="replace") as fh:
            return fh.readlines()
    except OSError:
        return []


# ---------------------------------------------------------------------------
# Determine scan roots.
#   - Module TARGET_PATH: view/frontend/{templates,web}.
#   - Theme or theme-override TARGET_PATH (no view/frontend/ inside): the path itself.
#   - Theme-override roots the caller resolves per references/theme-discovery.md
#     (e.g. app/design/frontend/<Vendor>/<Theme>/<Module>/templates) are passed in via
#     EXTRA_SCAN_ROOTS so a single run covers both the module's own templates and the
#     theme overrides that actually render.
# ---------------------------------------------------------------------------
scan_roots = []
template_root = os.path.join(target_path, "view", "frontend", "templates")
if os.path.isdir(template_root):
    scan_roots.append(template_root)

web_root = os.path.join(target_path, "view", "frontend", "web")
if os.path.isdir(web_root):
    scan_roots.append(web_root)

# Also scan the target_path directly if it looks like a theme (has web/ or *.phtml at top level)
if not scan_roots and os.path.isdir(target_path):
    scan_roots.append(target_path)

# Append caller-resolved theme-override roots (deduped; existing directories only).
_extra = os.environ.get("EXTRA_SCAN_ROOTS", "")
for _root in _extra.replace(os.pathsep, "\n").split("\n"):
    _root = _root.strip()
    if _root and os.path.isdir(_root) and _root not in scan_roots:
        scan_roots.append(_root)

TEMPLATE_EXTS = {".phtml", ".html"}
STYLE_EXTS = {".less", ".css"}

# ---------------------------------------------------------------------------
# 1. Collect all template files and style files.
# ---------------------------------------------------------------------------
template_files = []
style_files = []

for root in scan_roots:
    for fpath, ext in walk_files(root, TEMPLATE_EXTS | STYLE_EXTS):
        if ext in TEMPLATE_EXTS:
            template_files.append(fpath)
        else:
            style_files.append(fpath)

# ---------------------------------------------------------------------------
# 2. Template checks.
# ---------------------------------------------------------------------------
# Templates are normalised before matching: every PHP block and HTML comment is blanked to the same
# length (newlines kept, so offsets and line numbers survive), then tags are matched across lines.
# Line-window heuristics missed attributes that sit lines away from `<tag` (after PHP conditionals)
# and labels elsewhere in the file. An echo (`<?= ?>`) becomes DYN chars: text in element content,
# "attributes unknown until runtime" when bare inside a tag.
DYN = "\x01"
PHP_BLOCK_RE = re.compile(r'<\?(=|php\b)(.*?)(?:\?>|\Z)', re.S | re.I)
PHP_ECHO_RE = re.compile(r'\b(?:echo|print)\b', re.I)
HTML_COMMENT_RE = re.compile(r'<!--.*?(?:-->|\Z)', re.S)
KO_TEXT_COMMENT_RE = re.compile(r'^<!--\s*ko\s+(?:text|html|i18n)\s*:', re.I)
TAG_RE = re.compile(r'<([a-zA-Z][\w:.-]*)((?:[^>"\']|"[^"]*"|\'[^\']*\')*)>', re.S)
CLOSE_TAG_RE = re.compile(r'</[a-zA-Z][\w:.-]*\s*>')
ATTR_RE = re.compile(r'([^\s"\'=<>/`]+)(?:\s*=\s*("[^"]*"|\'[^\']*\'|[^\s"\'>]+))?')
KO_BIND_ATTRS = ("data-bind", "attr", "ko-attr")
KO_TEXT_RE = re.compile(r'(?<![\w-])(?:text|html|i18n)\s*:', re.I)
TEXT_BIND_ATTRS = {"x-text", "x-html", "v-text", "v-html", "translate", "text", "html", "i18n"}

FIELDSET_TAG_RE = re.compile(r'<fieldset\b', re.IGNORECASE)
LEGEND_TAG_RE   = re.compile(r'<legend\b', re.IGNORECASE)
SKIP_LINK_RE = re.compile(r'href\s*=\s*["\']#[^"\']+["\']', re.IGNORECASE)

VALID_ARIA_ROLES = {
    "alert", "alertdialog", "application", "article", "banner", "button",
    "cell", "checkbox", "columnheader", "combobox", "complementary",
    "contentinfo", "definition", "dialog", "directory", "document",
    "feed", "figure", "form", "grid", "gridcell", "group", "heading",
    "img", "link", "list", "listbox", "listitem", "log", "main",
    "marquee", "math", "menu", "menubar", "menuitem", "menuitemcheckbox",
    "menuitemradio", "navigation", "none", "note", "option", "presentation",
    "progressbar", "radio", "radiogroup", "region", "row", "rowgroup",
    "rowheader", "scrollbar", "search", "searchbox", "separator",
    "slider", "spinbutton", "status", "switch", "tab", "table",
    "tablist", "tabpanel", "term", "textbox", "timer", "toolbar",
    "tooltip", "tree", "treegrid", "treeitem",
}


def _blank(s, fill):
    return "".join(c if c == "\n" else fill for c in s)


def normalise(text):
    def php(m):
        echo = m.group(1) == "=" or PHP_ECHO_RE.search(m.group(2) or "")
        return _blank(m.group(0), DYN if echo else " ")
    text = PHP_BLOCK_RE.sub(php, text)

    def comment(m):
        return _blank(m.group(0), DYN if KO_TEXT_COMMENT_RE.match(m.group(0)) else " ")
    return HTML_COMMENT_RE.sub(comment, text)


class Tag:
    """One start tag: name, attrs {lname: (masked, original)}, dyn (bare echo in the tag)."""

    def __init__(self, m, original):
        self.name = m.group(1).lower()
        self.start, self.end = m.start(), m.end()
        self.attrs = {}
        self.dyn = False
        base = m.start(2)
        for am in ATTR_RE.finditer(m.group(2)):
            aname = am.group(1)
            if DYN in aname:
                self.dyn = True
                continue
            masked = orig = ""
            if am.group(2) is not None:
                masked = am.group(2)
                orig = original[base + am.start(2):base + am.end(2)]
                if masked[:1] in "\"'":
                    masked, orig = masked[1:-1], orig[1:-1]
            self.attrs.setdefault(aname.lower(), (masked, " ".join(orig.split())))

    def static(self, name):
        """Non-empty static value (PHP-interpolated counts), or None."""
        v = self.attrs.get(name)
        return v[1] if v and v[0].strip() else None

    def has(self, name):
        return name in self.attrs

    def bound(self, name):
        """Alpine/Vue/KO-bound expression for attribute `name`, or None."""
        for pre in (":", "x-bind:", "v-bind:"):
            if pre + name in self.attrs:
                return self.attrs[pre + name][1] or "?"
        key = re.compile(r'(?:^|[{,\s])[\'"]?' + re.escape(name) + r'[\'"]?\s*:\s*([^,}\s]+)', re.I)
        for ko in KO_BIND_ATTRS:
            if ko in self.attrs:
                km = key.search(self.attrs[ko][1])
                if km:
                    return km.group(1)
        return None

    def named(self):
        return any(self.static(a) or self.bound(a) for a in ("aria-label", "aria-labelledby", "title"))

    def text_bound(self):
        if any(a in self.attrs for a in TEXT_BIND_ATTRS):
            return True
        return any(ko in self.attrs and KO_TEXT_RE.search(self.attrs[ko][1]) for ko in ("data-bind",))


def scan_template(fpath, text):
    masked = normalise(text)
    nl = [i for i, c in enumerate(masked) if c == "\n"]

    def line_of(pos):
        return bisect.bisect_right(nl, pos - 1) + 1

    tags = [Tag(m, text) for m in TAG_RE.finditer(masked)]

    label_for_static, label_for_bound, label_spans = set(), set(), []
    for t in tags:
        if t.name != "label":
            continue
        if t.static("for"):
            label_for_static.add(t.static("for"))
        if t.bound("for"):
            label_for_bound.add(t.bound("for"))
        close = re.compile(r'</label\s*>', re.I).search(masked, t.end)
        label_spans.append((t.start, close.end() if close else t.end))

    def labelled(t):
        if t.dyn or t.named():
            return True
        if any(s <= t.start < e for s, e in label_spans):
            return True
        if t.static("id") and t.static("id") in label_for_static:
            return True
        bid = t.bound("id")
        # `uid`: Magento ui/form/field wraps element templates in <label attr="for: uid">.
        return bool(bid) and (bid in label_for_bound or bid == "uid")

    def inner_accessible(t):
        close = re.compile(r'</' + re.escape(t.name) + r'\s*>', re.I).search(masked, t.end)
        if not close:
            return True  # can't see the content: don't guess
        inner = masked[t.end:close.start()]
        for im in TAG_RE.finditer(inner):
            it = Tag(im, text[t.end:close.start()])
            if it.dyn or it.named() or it.text_bound() or it.name == "text":
                return True
            if it.name == "img" and (it.static("alt") or it.bound("alt")):
                return True
        stripped = CLOSE_TAG_RE.sub("", TAG_RE.sub("", inner))
        return bool(stripped.strip())

    last_heading_level = 0
    for t in tags:
        line = line_of(t.start)

        # --- Rule A1: <img> missing alt ---
        if t.name == "img" and not (t.dyn or t.has("alt") or t.bound("alt")):
            finding(
                "high",
                "<img> tag missing alt attribute",
                fpath, line,
                "Add alt=\"\" for decorative images or a descriptive alt text for informational images.",
                "Re-run scan or use axe DevTools browser extension to verify.",
                category="alt-text",
                tags=["wcag", "wcag-1.1.1", "alt-text"],
            )

        # --- Rule F1: form control without label ---
        if t.name == "input":
            input_type = (t.static("type") or "text").lower()
            if input_type not in {"hidden", "submit", "button", "reset", "image"} and not labelled(t):
                finding(
                    "high",
                    "Form input without associated label",
                    fpath, line,
                    "Add <label for=\"field-id\">Label</label> or aria-label=\"Label\" to the input.",
                    "Re-run scan; verify with screen reader or axe DevTools.",
                    category="forms",
                    tags=["wcag", "wcag-1.3.1", "wcag-4.1.2", "forms"],
                )
        if t.name in ("select", "textarea") and not labelled(t):
            finding(
                "high",
                f"<{t.name}> without associated label",
                fpath, line,
                f"Add <label for=\"field-id\">Label</label> or aria-label=\"Label\" to the <{t.name}>.",
                "Re-run scan; verify with screen reader or axe DevTools.",
                category="forms",
                tags=["wcag", "wcag-1.3.1", "wcag-4.1.2", "forms"],
            )

        # --- Rule H1: heading order skip ---
        if re.fullmatch(r'h[1-6]', t.name):
            level = int(t.name[1])
            if last_heading_level > 0 and level > last_heading_level + 1:
                finding(
                    "medium",
                    f"Heading order skip: h{last_heading_level} followed by h{level}",
                    fpath, line,
                    f"Use h{last_heading_level + 1} instead of h{level} to maintain a logical heading hierarchy.",
                    "Re-run scan; verify heading structure with axe DevTools.",
                    category="semantic-html",
                    tags=["wcag", "wcag-1.3.1", "semantic-html"],
                )
            last_heading_level = level

        # --- Rule K2: positive tabindex ---
        tabindex = None
        try:
            tabindex = int(t.static("tabindex") or "")
        except ValueError:
            pass
        if tabindex is not None and tabindex > 0:
            finding(
                "medium",
                f"Positive tabindex={tabindex} disrupts natural tab order",
                fpath, line,
                "Remove positive tabindex. Use tabindex=\"0\" to include in natural order or tabindex=\"-1\" for programmatic focus.",
                "Re-run scan; test keyboard navigation order.",
                category="keyboard",
                tags=["wcag", "wcag-2.4.3", "keyboard"],
            )

        # --- Rule L1: <a> with no accessible text (name-only anchors excluded) ---
        if t.name == "a" and not t.dyn and any(t.has(a) or t.bound(a) for a in ("href", "role", "tabindex")):
            if not (t.named() or t.text_bound() or inner_accessible(t)):
                finding(
                    "high",
                    "<a> tag with no accessible text",
                    fpath, line,
                    "Add descriptive link text, aria-label, or a visually-hidden <span> with meaningful text.",
                    "Re-run scan; test with screen reader; use axe DevTools.",
                    category="aria",
                    tags=["wcag", "wcag-2.4.4", "wcag-4.1.2", "aria"],
                )

        # --- Rule L2: <button> with no accessible text ---
        if t.name == "button" and not t.dyn:
            if not (t.named() or t.text_bound() or inner_accessible(t)):
                finding(
                    "high",
                    "<button> tag with no accessible text",
                    fpath, line,
                    "Add a text label, aria-label, or visually-hidden <span> to every <button>.",
                    "Re-run scan; test with screen reader.",
                    category="aria",
                    tags=["wcag", "wcag-4.1.2", "aria"],
                )

        # --- Rule G1: <html> missing lang ---
        if t.name == "html" and not (t.dyn or t.has("lang") or t.bound("lang")):
            finding(
                "low",
                "<html> tag missing lang attribute",
                fpath, line,
                'Add lang="en" (or appropriate BCP-47 tag) to the <html> element.',
                "Re-run scan; verify with axe DevTools.",
                category="semantic-html",
                tags=["wcag", "wcag-3.1.1", "semantic-html"],
            )

        # --- Rule AR1: invalid ARIA role (a literal role= only; data-role / :role are not ARIA) ---
        role = t.attrs.get("role")
        if role and role[0].strip() and DYN not in role[0]:
            role_val = role[0].strip().lower()
            # Fallback lists ("switch checkbox") are valid when any token is.
            if not any(tok in VALID_ARIA_ROLES for tok in role_val.split()):
                finding(
                    "medium",
                    f"Invalid or unrecognized ARIA role: role=\"{role_val}\"",
                    fpath, line,
                    f"Replace role=\"{role_val}\" with a valid WAI-ARIA role or the appropriate semantic HTML element.",
                    "Re-run scan; verify role list at https://www.w3.org/TR/wai-aria-1.1/#role_definitions.",
                    category="aria",
                    tags=["wcag", "wcag-4.1.2", "aria"],
                )

        # --- Rule AR2: aria-hidden on a focusable element (intrinsic tag OR tabindex >= 0) ---
        if (t.static("aria-hidden") or "").lower() == "true":
            if tabindex is not None:
                # tabindex="-1" takes it out of the tab order (duplicate card-link pattern).
                focusable = tabindex >= 0
            else:
                focusable = (
                    t.name in ("button", "select", "textarea")
                    or (t.name == "input" and (t.static("type") or "").lower() != "hidden")
                    or (t.name == "a" and (t.has("href") or bool(t.bound("href"))))
                    or t.has("contenteditable")
                )
            if focusable:
                finding(
                    "high",
                    "aria-hidden=\"true\" on a potentially focusable element",
                    fpath, line,
                    "Remove aria-hidden from focusable elements, or add tabindex=\"-1\" before hiding from AT.",
                    "Re-run scan; test with screen reader to confirm element is not announced while focused.",
                    category="aria",
                    tags=["wcag", "wcag-4.1.2", "aria"],
                )

    # --- Rule F2: fieldset without legend (line window over the normalised text) ---
    mlines = masked.split("\n")
    for idx, mline in enumerate(mlines):
        if FIELDSET_TAG_RE.search(mline):
            window = "\n".join(mlines[idx:idx + 11])
            if not LEGEND_TAG_RE.search(window):
                finding(
                    "medium",
                    "<fieldset> missing <legend>",
                    fpath, idx + 1,
                    "Add <legend>Group label</legend> as the first child of <fieldset>.",
                    "Re-run scan; verify with screen reader.",
                    category="forms",
                    tags=["wcag", "wcag-1.3.1", "forms"],
                )


for fpath in template_files:
    lines = read_lines(fpath)
    if not lines:
        continue
    full_text = "".join(lines)

    # --- Rule K1: missing skip-link (root layouts only) ---
    if ROOT_LAYOUT_PATTERNS.search(fpath) and not SKIP_LINK_RE.search(full_text):
        finding(
            "medium",
            "Root layout template missing skip-link",
            fpath, 1,
            'Add <a href="#maincontent" class="skip">Skip to main content</a> as the first focusable element.',
            "Re-run scan; navigate the page with Tab key and confirm a skip link appears.",
            category="keyboard",
            tags=["wcag", "wcag-2.4.1", "keyboard"],
        )

    scan_template(fpath, full_text)

# ---------------------------------------------------------------------------
# 3. LESS/CSS color-contrast heuristics (Rule C1 — heuristic only).
#    Skip for Hyva projects (Tailwind classes; LESS not applicable).
# ---------------------------------------------------------------------------
if not is_hyva:
    # Very light gray / near-white foreground colors as a proxy for low contrast.
    LOW_CONTRAST_RE = re.compile(
        r'(?:color|fill)\s*:\s*'
        r'(?:'
        r'#(?:[c-f][0-9a-f]{5}|[c-f][0-9a-f]{2})'   # light hex colors
        r'|rgba?\(\s*(?:2[0-4][0-9]|25[0-5])'        # RGB values 200-255 (very light)
        r')',
        re.IGNORECASE,
    )

    for fpath in style_files:
        lines = read_lines(fpath)
        for lineno, line in enumerate(lines, start=1):
            if LOW_CONTRAST_RE.search(line):
                finding(
                    "medium",
                    "Potential low-contrast color value (heuristic — verify with browser tool)",
                    fpath, lineno,
                    "Use WebAIM Contrast Checker to verify ratio >= 4.5:1 (normal text) or >= 3:1 (large text).",
                    "Check rendered contrast with axe DevTools, Lighthouse, or browser DevTools accessibility inspector.",
                    category="contrast",
                    tags=["wcag", "wcag-1.4.3", "contrast", "heuristic"],
                )

print(json.dumps(findings, indent=2))
PY
