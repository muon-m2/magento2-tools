#!/usr/bin/env bash
# scan-templates.sh — read-only STATIC accessibility scan of storefront templates.
#
# Scans .phtml/.html templates and .less/.css files under TARGET_PATH for WCAG 2.1
# Level AA issues, outputting a JSON array of finding objects conforming to
# magento2-context/references/findings-schema.md.
#
# See references/wcag-rules.md for the full check catalog.
# See references/theme-discovery.md for template location rules.
#
# Inputs (env vars or positional):
#   TARGET_PATH   Path to the module root or theme root (required, or $1)
#   TARGET_MODULE Module name, e.g. "Acme_Storefront" (default: derived from module.xml)
#   THEME         Active frontend theme, e.g. "hyva" or "Magento/luma" (default: "")
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
python3 <<'PY'
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


def finding(severity, category, title, file_path, line, recommendation,
            verification, subcategory=None, tags=None, extra_evidence=None):
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
    if subcategory:
        f["subcategory"] = subcategory
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
# Determine scan roots: module templates + theme overrides.
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
IMG_TAG_RE = re.compile(r'<img\b', re.IGNORECASE)
IMG_ALT_RE = re.compile(r'\balt\s*=\s*["\']', re.IGNORECASE)

INPUT_TAG_RE = re.compile(r'<input\b', re.IGNORECASE)
INPUT_TYPE_RE = re.compile(r'\btype\s*=\s*["\']([^"\']+)["\']', re.IGNORECASE)
LABEL_FOR_RE  = re.compile(r'<label\b[^>]*\bfor\s*=', re.IGNORECASE)
ARIA_LABEL_RE = re.compile(r'\baria-label(ledby)?\s*=', re.IGNORECASE)

SELECT_TAG_RE   = re.compile(r'<select\b', re.IGNORECASE)
TEXTAREA_TAG_RE = re.compile(r'<textarea\b', re.IGNORECASE)
FIELDSET_TAG_RE = re.compile(r'<fieldset\b', re.IGNORECASE)
LEGEND_TAG_RE   = re.compile(r'<legend\b', re.IGNORECASE)

HEADING_RE = re.compile(r'<(h[1-6])\b', re.IGNORECASE)

SKIP_LINK_RE = re.compile(r'href\s*=\s*["\']#[^"\']+["\']', re.IGNORECASE)

TABINDEX_RE = re.compile(r'\btabindex\s*=\s*["\']([^"\']+)["\']', re.IGNORECASE)

A_TAG_RE      = re.compile(r'<a\b[^>]*>', re.IGNORECASE)
BUTTON_TAG_RE = re.compile(r'<button\b[^>]*>', re.IGNORECASE)
TAG_TEXT_RE   = re.compile(r'>([^<]+)<', re.IGNORECASE)
ARIA_HIDDEN_RE = re.compile(r'\baria-hidden\s*=\s*["\']true["\']', re.IGNORECASE)
FOCUSABLE_RE   = re.compile(r'<(a|button|input|select|textarea)\b', re.IGNORECASE)

HTML_TAG_RE = re.compile(r'<html\b', re.IGNORECASE)
HTML_LANG_RE = re.compile(r'\blang\s*=\s*["\']', re.IGNORECASE)

ROLE_RE = re.compile(r'\brole\s*=\s*["\']([^"\']+)["\']', re.IGNORECASE)

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

# Screen-reader-only class names (Luma + Hyva)
SR_ONLY_RE = re.compile(r'class\s*=\s*["\'][^"\']*(?:visually-hidden|sr-only)[^"\']*["\']', re.IGNORECASE)


def has_accessible_text_nearby(lines, tag_line_idx, window=5):
    """Check if lines near the tag contain accessible text or sr-only spans."""
    start = max(0, tag_line_idx - 1)
    end = min(len(lines), tag_line_idx + window)
    snippet = "".join(lines[start:end])
    if ARIA_LABEL_RE.search(snippet):
        return True
    if SR_ONLY_RE.search(snippet):
        return True
    # Non-empty text node
    for m in TAG_TEXT_RE.finditer(snippet):
        if m.group(1).strip():
            return True
    return False


for fpath in template_files:
    lines = read_lines(fpath)
    if not lines:
        continue

    full_text = "".join(lines)
    is_root_layout = bool(ROOT_LAYOUT_PATTERNS.search(fpath))
    last_heading_level = 0

    for lineno, line in enumerate(lines, start=1):

        # --- Rule A1: <img> missing alt ---
        if IMG_TAG_RE.search(line):
            # Check 2 lines around for alt attribute
            window = "".join(lines[max(0, lineno - 2):min(len(lines), lineno + 2)])
            if not IMG_ALT_RE.search(window):
                finding(
                    "high", "accessibility",
                    "<img> tag missing alt attribute",
                    fpath, lineno,
                    "Add alt=\"\" for decorative images or a descriptive alt text for informational images.",
                    "Re-run scan or use axe DevTools browser extension to verify.",
                    subcategory="alt-text",
                    tags=["wcag", "wcag-1.1.1", "alt-text"],
                )

        # --- Rule F1: form input without label ---
        if INPUT_TAG_RE.search(line):
            type_match = INPUT_TYPE_RE.search(line)
            input_type = type_match.group(1).lower() if type_match else "text"
            excluded_types = {"hidden", "submit", "button", "reset", "image"}
            if input_type not in excluded_types:
                window_lines = lines[max(0, lineno - 5):min(len(lines), lineno + 5)]
                window = "".join(window_lines)
                has_label = LABEL_FOR_RE.search(window) or ARIA_LABEL_RE.search(window)
                if not has_label:
                    finding(
                        "high", "accessibility",
                        "Form input without associated label",
                        fpath, lineno,
                        "Add <label for=\"field-id\">Label</label> or aria-label=\"Label\" to the input.",
                        "Re-run scan; verify with screen reader or axe DevTools.",
                        subcategory="forms",
                        tags=["wcag", "wcag-1.3.1", "wcag-4.1.2", "forms"],
                    )

        # --- Rule F1 (select/textarea without label) ---
        for tag_re, tag_name in [(SELECT_TAG_RE, "select"), (TEXTAREA_TAG_RE, "textarea")]:
            if tag_re.search(line):
                window_lines = lines[max(0, lineno - 5):min(len(lines), lineno + 5)]
                window = "".join(window_lines)
                has_label = LABEL_FOR_RE.search(window) or ARIA_LABEL_RE.search(window)
                if not has_label:
                    finding(
                        "high", "accessibility",
                        f"<{tag_name}> without associated label",
                        fpath, lineno,
                        f"Add <label for=\"field-id\">Label</label> or aria-label=\"Label\" to the <{tag_name}>.",
                        "Re-run scan; verify with screen reader or axe DevTools.",
                        subcategory="forms",
                        tags=["wcag", "wcag-1.3.1", "wcag-4.1.2", "forms"],
                    )

        # --- Rule F2: fieldset without legend ---
        if FIELDSET_TAG_RE.search(line):
            window = "".join(lines[lineno - 1:min(len(lines), lineno + 10)])
            if not LEGEND_TAG_RE.search(window):
                finding(
                    "medium", "accessibility",
                    "<fieldset> missing <legend>",
                    fpath, lineno,
                    "Add <legend>Group label</legend> as the first child of <fieldset>.",
                    "Re-run scan; verify with screen reader.",
                    subcategory="forms",
                    tags=["wcag", "wcag-1.3.1", "forms"],
                )

        # --- Rule H1: heading order skip ---
        h_match = HEADING_RE.search(line)
        if h_match:
            level = int(h_match.group(1)[1])
            if last_heading_level > 0 and level > last_heading_level + 1:
                finding(
                    "medium", "accessibility",
                    f"Heading order skip: h{last_heading_level} followed by h{level}",
                    fpath, lineno,
                    f"Use h{last_heading_level + 1} instead of h{level} to maintain a logical heading hierarchy.",
                    "Re-run scan; verify heading structure with axe DevTools.",
                    subcategory="semantic-html",
                    tags=["wcag", "wcag-1.3.1", "semantic-html"],
                )
            last_heading_level = level

        # --- Rule K1: missing skip-link (root layouts only) ---
        if is_root_layout and lineno == 1:
            if not SKIP_LINK_RE.search(full_text):
                finding(
                    "medium", "accessibility",
                    "Root layout template missing skip-link",
                    fpath, 1,
                    'Add <a href="#maincontent" class="skip">Skip to main content</a> as the first focusable element.',
                    "Re-run scan; navigate the page with Tab key and confirm a skip link appears.",
                    subcategory="keyboard",
                    tags=["wcag", "wcag-2.4.1", "keyboard"],
                )

        # --- Rule K2: positive tabindex ---
        ti_match = TABINDEX_RE.search(line)
        if ti_match:
            try:
                ti_val = int(ti_match.group(1).strip())
                if ti_val > 0:
                    finding(
                        "medium", "accessibility",
                        f"Positive tabindex={ti_val} disrupts natural tab order",
                        fpath, lineno,
                        "Remove positive tabindex. Use tabindex=\"0\" to include in natural order or tabindex=\"-1\" for programmatic focus.",
                        "Re-run scan; test keyboard navigation order.",
                        subcategory="keyboard",
                        tags=["wcag", "wcag-2.4.3", "keyboard"],
                    )
            except ValueError:
                pass

        # --- Rule L1: <a> with no accessible text ---
        if A_TAG_RE.search(line):
            if not has_accessible_text_nearby(lines, lineno - 1):
                # Also check for title= as an acceptable alternative
                if "title=" not in line.lower():
                    finding(
                        "high", "accessibility",
                        "<a> tag with no accessible text",
                        fpath, lineno,
                        "Add descriptive link text, aria-label, or a visually-hidden <span> with meaningful text.",
                        "Re-run scan; test with screen reader; use axe DevTools.",
                        subcategory="aria",
                        tags=["wcag", "wcag-2.4.4", "wcag-4.1.2", "aria"],
                    )

        # --- Rule L2: <button> with no accessible text ---
        if BUTTON_TAG_RE.search(line):
            if not has_accessible_text_nearby(lines, lineno - 1):
                finding(
                    "high", "accessibility",
                    "<button> tag with no accessible text",
                    fpath, lineno,
                    "Add a text label, aria-label, or visually-hidden <span> to every <button>.",
                    "Re-run scan; test with screen reader.",
                    subcategory="aria",
                    tags=["wcag", "wcag-4.1.2", "aria"],
                )

        # --- Rule G1: <html> missing lang ---
        if HTML_TAG_RE.search(line):
            if not HTML_LANG_RE.search(line):
                finding(
                    "low", "accessibility",
                    "<html> tag missing lang attribute",
                    fpath, lineno,
                    'Add lang="en" (or appropriate BCP-47 tag) to the <html> element.',
                    "Re-run scan; verify with axe DevTools.",
                    subcategory="semantic-html",
                    tags=["wcag", "wcag-3.1.1", "semantic-html"],
                )

        # --- Rule AR1: invalid ARIA role ---
        role_match = ROLE_RE.search(line)
        if role_match:
            role_val = role_match.group(1).strip().lower()
            if role_val not in VALID_ARIA_ROLES:
                finding(
                    "medium", "accessibility",
                    f"Invalid or unrecognized ARIA role: role=\"{role_val}\"",
                    fpath, lineno,
                    f"Replace role=\"{role_val}\" with a valid WAI-ARIA role or the appropriate semantic HTML element.",
                    "Re-run scan; verify role list at https://www.w3.org/TR/wai-aria-1.1/#role_definitions.",
                    subcategory="aria",
                    tags=["wcag", "wcag-4.1.2", "aria"],
                )

        # --- Rule AR2: aria-hidden on focusable element ---
        if ARIA_HIDDEN_RE.search(line) and FOCUSABLE_RE.search(line):
            finding(
                "high", "accessibility",
                "aria-hidden=\"true\" on a potentially focusable element",
                fpath, lineno,
                "Remove aria-hidden from focusable elements, or add tabindex=\"-1\" before hiding from AT.",
                "Re-run scan; test with screen reader to confirm element is not announced while focused.",
                subcategory="aria",
                tags=["wcag", "wcag-4.1.2", "aria"],
            )

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
                    "medium", "accessibility",
                    "Potential low-contrast color value (heuristic — verify with browser tool)",
                    fpath, lineno,
                    "Use WebAIM Contrast Checker to verify ratio >= 4.5:1 (normal text) or >= 3:1 (large text).",
                    "Check rendered contrast with axe DevTools, Lighthouse, or browser DevTools accessibility inspector.",
                    subcategory="contrast",
                    tags=["wcag", "wcag-1.4.3", "contrast", "heuristic"],
                )

print(json.dumps(findings, indent=2))
PY
