# WCAG Static Check Catalog

Static a11y checks performed by `scripts/scan-templates.sh` on `.phtml` / `.html` /
`.less` / `.css` files. Each check maps to a WCAG 2.1 success criterion (SC). No running
Magento instance is required.

Cross-references:
- Severity levels: `magento2-context/references/severity.md`
- Finding shape: `magento2-context/references/findings-schema.md`

---

## SC 1.1.1 — Non-text Content

**Rule A1 — `<img>` missing `alt`**

Pattern: `<img` without a following `alt=` attribute on the same or next line.

- Severity: `high`
- Subcategory: `alt-text`
- Fix: Add `alt=""` (empty string) for decorative images; add a descriptive `alt` for
  informational images.
- WCAG SC: 1.1.1
- Note: `alt=""` is valid and correct for purely decorative images (e.g. spacers).
  The check flags only the total absence of the attribute.

---

## SC 1.3.1 / 4.1.2 — Form Labels

**Rule F1 — Form input without label**

Pattern: `<input` (type != `hidden`, `submit`, `button`, `reset`, `image`) that is NOT
preceded or followed (within 5 lines) by any of:
- A `<label` element with a matching `for=` attribute
- An `aria-label=` attribute on the `<input>` itself
- An `aria-labelledby=` attribute on the `<input>` itself

Also flags `<select` and `<textarea` without an associated label.

- Severity: `high`
- Subcategory: `forms`
- Fix: Add `<label for="field-id">Label</label>` or `aria-label="Label"` directly on
  the control.
- WCAG SC: 1.3.1, 4.1.2

**Rule F2 — `<fieldset>` missing `<legend>`**

Pattern: `<fieldset` without a `<legend>` descendant in the same template block.

- Severity: `medium`
- Subcategory: `forms`
- Fix: Add `<legend>Group label</legend>` as the first child of `<fieldset>`.
- WCAG SC: 1.3.1

---

## SC 1.3.1 — Heading Order

**Rule H1 — Heading-order skip**

Pattern: A heading tag (h1–h6) whose level is more than one step lower than the
preceding heading tag in the same file (e.g. `<h1>` then `<h3>` without an intervening
`<h2>`).

- Severity: `medium`
- Subcategory: `semantic-html`
- Fix: Ensure headings descend by one level at a time. Use CSS, not heading levels, for
  visual sizing.
- WCAG SC: 1.3.1
- Note: This check operates per-file. Cross-file heading order (e.g. across layout
  handles) cannot be verified statically.

---

## SC 2.4.1 — Bypass Blocks (Skip Link)

**Rule K1 — Missing skip-link**

Pattern: A layout root template (`default.phtml`, `1column.phtml`, `2columns-left.phtml`,
etc.) or a `<body>`-opening file that does NOT contain `href="#` pointing to a main
content anchor, or a visually-hidden skip-link pattern.

- Severity: `medium`
- Subcategory: `keyboard`
- Fix: Add `<a href="#maincontent" class="skip">Skip to main content</a>` as the first
  focusable element in the page layout template, with a corresponding `id="maincontent"`
  on the `<main>` element.
- WCAG SC: 2.4.1
- Note: Only checked in root layout templates (files whose name matches common Magento
  layout root patterns). Module-level partials are not expected to include skip links.

---

## SC 2.4.3 — Focus Order / Tab Index

**Rule K2 — Positive `tabindex`**

Pattern: `tabindex=` with a value > 0.

- Severity: `medium`
- Subcategory: `keyboard`
- Fix: Remove the positive `tabindex`. Reorder DOM elements or use `tabindex="0"` to
  include an element in natural tab order. Reserve `tabindex="-1"` for programmatic focus
  only.
- WCAG SC: 2.4.3

---

## SC 2.4.4 / 4.1.2 — Link / Button Accessible Text

**Rule L1 — `<a>` with no accessible text**

Pattern: `<a` tag that has no visible text content, no `aria-label=`, no `aria-labelledby=`,
and no `title=` attribute. Also flags `<a><img>...</a>` where the `<img>` has `alt=""`.

- Severity: `high`
- Subcategory: `aria`
- Fix: Add descriptive link text, `aria-label`, or a visually-hidden `<span>` with
  meaningful text. Avoid "click here" or "read more" without context.
- WCAG SC: 2.4.4, 4.1.2

**Rule L2 — `<button>` with no accessible text**

Pattern: `<button` tag with no visible text content, no `aria-label=`, no `aria-labelledby=`,
and no `title=`.

- Severity: `high`
- Subcategory: `aria`
- Fix: Add a text label or `aria-label` to every `<button>`.
- WCAG SC: 4.1.2

---

## SC 3.1.1 — Language of Page

**Rule G1 — Missing `lang` on `<html>`**

Pattern: An `<html` tag without a `lang=` attribute.

- Severity: `low`
- Subcategory: `semantic-html`
- Fix: Add `lang="en"` (or the appropriate BCP-47 language tag) to every root `<html>`
  element. In Magento, this is typically set in `page/html/head.phtml`.
- WCAG SC: 3.1.1
- Note: Per-page language is set in Magento's root template. Module partials are not
  expected to carry `<html>` tags; this rule only fires when an `<html>` tag is found
  without `lang=`.

---

## SC 4.1.2 — ARIA Role Misuse

**Rule AR1 — Invalid ARIA role**

Pattern: `role="<value>"` where `<value>` is not a recognized WAI-ARIA role (e.g. a typo
like `role="buton"` or an invented role like `role="clickable"`). Note: this check flags
unrecognized role *names* only — it does not detect a valid role (e.g. `role="button"`)
applied to the wrong element.

- Severity: `medium`
- Subcategory: `aria`
- Fix: Use the correct semantic HTML element (`<button>`, `<nav>`, `<main>`, etc.)
  instead of ARIA roles where possible. When ARIA roles are necessary, pair them with
  the required keyboard interaction (e.g. `role="button"` requires `tabindex="0"` and
  `keydown` handler).
- WCAG SC: 4.1.2

**Rule AR2 — `aria-hidden="true"` on a focusable element**

Pattern: `aria-hidden="true"` combined with a focusable element (`<a`, `<button`,
`<input`, `<select`, `<textarea`, `tabindex`).

- Severity: `high`
- Subcategory: `aria`
- Fix: Remove `aria-hidden="true"` from focusable elements, or remove the element from
  the tab order with `tabindex="-1"` before hiding it from AT.
- WCAG SC: 4.1.2

---

## SC 1.4.3 — Color Contrast (Heuristic)

**Rule C1 — Hardcoded low-contrast color pair in LESS/CSS**

Pattern: LESS/CSS files that define both a foreground color variable and a background
color variable with values that are clearly low-contrast (e.g. light grey text on white,
or very similar hue values). This is a **heuristic-only** check — static analysis cannot
reliably compute the exact contrast ratio without rendering.

- Severity: `medium`
- Subcategory: `contrast`
- Fix: Use the WebAIM Contrast Checker to verify the ratio is ≥ 4.5:1 (normal text)
  or ≥ 3:1 (large text / UI components). Update color variables in the theme or module
  LESS files.
- WCAG SC: 1.4.3
- **Important caveat:** This check reports potential contrast issues based on raw color
  values. It CANNOT fully verify contrast statically because final rendered values depend
  on LESS compilation, inheritance, and browser defaults. Use a browser-based tool
  (e.g. axe DevTools, Lighthouse) for authoritative contrast results.

---

## Luma vs. Hyva Notes

Patterns to be aware of per theme (see `references/theme-discovery.md` for locations):

| Pattern | Luma | Hyva |
|---------|------|------|
| JS binding | `data-bind="..."` (Knockout) | `x-data`, `x-bind`, `@click` (Alpine) |
| Component containers | `<div data-mage-init='...'>` | `<div x-data="...">` |
| CSS framework | LESS (compiled) | Tailwind (utility classes) |
| Screen-reader utilities | `.visually-hidden` LESS class | `sr-only` Tailwind class |

The scan normalizes both `class="visually-hidden"` and `class="sr-only"` as equivalent
screen-reader-only patterns when evaluating accessible text for links and buttons.
