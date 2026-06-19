# Theme Discovery for Accessibility Audit

Where storefront templates live, how to discover them, and how Luma and Hyva differ
for accessibility analysis purposes.

Cross-references:
- Active theme resolution: `magento2-context/references/theme-detection.md`
- Template scan script: `../scripts/scan-templates.sh`

---

## Template Locations

### Module-scoped templates

```
{magento_root}/app/code/{Vendor}/{Module}/view/frontend/templates/**/*.phtml
{magento_root}/app/code/{Vendor}/{Module}/view/frontend/templates/**/*.html
```

These are the primary templates for a module's storefront output.

### Theme-level overrides

```
{magento_root}/app/design/frontend/{Vendor}/{Theme}/{Module}/templates/**/*.phtml
{magento_root}/app/design/frontend/{Vendor}/{Theme}/**/*.html
```

Theme overrides take precedence over module templates at render time. Always scan both
locations when a theme override directory exists for the target module.

### Layout XML (not scanned for a11y)

Layout XML files (`.xml`) in `view/frontend/layout/` control which templates render and
their container structure. The scan does not parse layout XML for a11y findings, but
`references/wcag-rules.md` rule K1 (skip-link) checks root layout templates by name.

### LESS / CSS

```
{magento_root}/app/code/{Vendor}/{Module}/view/frontend/web/css/**/*.less
{magento_root}/app/code/{Vendor}/{Module}/view/frontend/web/css/**/*.css
{magento_root}/app/design/frontend/{Vendor}/{Theme}/web/css/**/*.less
{magento_root}/app/design/frontend/{Vendor}/{Theme}/web/css/**/*.css
```

Scanned only for color-contrast heuristics (WCAG SC 1.4.3). See
`references/wcag-rules.md` rule C1.

---

## Using `{ctx.theme}` from magento2-context

The `magento2-context` skill exposes the active frontend theme as `{ctx.theme}` (field
`theme.frontend` in the JSON). Use it to:

1. **Locate theme-level overrides.** When `ctx.theme` is non-null, also scan
   `app/design/frontend/{ctx.theme path}/` for template files. Pass the resolved
   override directories to `scan-templates.sh` via `EXTRA_SCAN_ROOTS` (os.pathsep- or
   newline-separated) so one scan covers both the module's own templates and the overrides.
2. **Adapt rule heuristics.** The scan script sets `THEME` from the context JSON and
   applies Luma vs. Hyva pattern adaptations.

```bash
# Consumer pattern (from magento2-context/references/theme-detection.md)
THEME=$(jq -r '.theme.frontend // "null"' .claude/.cache/magento2-context.json)
SRC=$(jq   -r '.theme.frontend_source // ""' .claude/.cache/magento2-context.json)

# Module scope: scan module templates + any theme override for this module in one run.
EXTRA_SCAN_ROOTS="$MAGENTO_ROOT/app/design/frontend/$SRC/$VENDOR_MODULE/templates" \
    THEME="$THEME" bash scan-templates.sh "$MODULE_PATH"
```

When `ctx.theme` is `null`, the scan proceeds on module templates only and notes the
theme as unknown in the findings `context` block.

---

## Luma vs. Hyva Differences

### Luma (default Magento theme)

- **CSS framework:** LESS compiled to CSS. Custom styles under `web/css/source/`.
- **JS binding:** RequireJS modules + Knockout (`data-bind="..."`, `ko.applyBindings`).
- **Screen-reader utility:** `.visually-hidden` LESS class (defined in
  `Magento_Theme/web/css/source/_extend.less`).
- **Component containers:** `data-mage-init='{"component": {...}}'` on DOM elements.
- **Template extension:** `.phtml` (PHP), compiled by Magento's block system.

A11y implications for Luma:
- Knockout-rendered text (`data-bind="text: ..."`) may not be present in the static
  `.phtml` source. Flag these as `info`-level gaps (cannot be verified without runtime).
- `.visually-hidden` on a `<span>` inside a `<button>` or `<a>` counts as accessible
  text for rules L1 and L2.

### Hyva (third-party, Tailwind + Alpine)

- **CSS framework:** Tailwind CSS utility classes. No LESS; styles are inline utility
  classes or a `tailwind.config.js`.
- **JS binding:** Alpine.js (`x-data`, `x-bind`, `@click`, `x-show`, `x-if`).
- **Screen-reader utility:** `sr-only` Tailwind class.
- **Component containers:** `<div x-data="initComponent()">` patterns.
- **Template extension:** `.phtml` (PHP), but often also `.html` for Alpine component
  templates loaded via `x-load`.

A11y implications for Hyva:
- `sr-only` class on a `<span>` inside a `<button>` or `<a>` counts as accessible
  text (equivalent to Luma's `.visually-hidden`).
- Alpine `@click` handlers on `<div>` elements require `role="button"` and `tabindex="0"`
  to be keyboard-accessible. The scan flags `@click` on non-interactive elements.
- Tailwind arbitrary color values (`text-[#abc]`, `bg-[#def]`) are treated as
  unknown-contrast (cannot evaluate statically); flag as `info`.
- LESS contrast heuristics (rule C1) do not apply to Hyva projects.

---

## Scan Priority Order

When both module and theme templates exist:

1. Scan module `view/frontend/templates/` first.
2. Scan theme overrides for the same module second.
3. A finding in a theme override file takes precedence (it is the template that actually
   renders); note the override path in the finding's `evidence[].file`.

---

## Root Layout Template Detection (Skip-Link Rule K1)

The skip-link check (WCAG 2.4.1) only applies to files whose name matches a root layout
pattern:

```
**/page/html/root.phtml
**/1column.phtml
**/2columns-left.phtml
**/2columns-right.phtml
**/3columns.phtml
**/empty.phtml
**/page-layout-*.phtml
```

Module-level partial templates are excluded from this check.
