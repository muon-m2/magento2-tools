# Breeze Child Theme Patterns

Reference for `magento2-breeze-child-theme`. Source: https://breezefront.com/docs/child-theme

## Directory layout

```
app/design/frontend/{Vendor}/{Theme}/
├── registration.php
├── theme.xml                       # <parent>Swissup/breeze-evolution</parent>
├── composer.json
├── media/
│   └── preview.jpg                 # admin thumbnail (optional)
└── web/
    ├── css/
    │   ├── breeze/
    │   │   └── _default.less       # Breeze-side styles (auto-included on every page)
    │   └── source/
    │       └── _extend.less        # Luma-side hook (blank/luma fallback)
    └── js/                         # theme JS (optional)
Magento_Theme/layout/breeze_default.xml   # Breeze-ONLY layout handle
```

## Choosing the parent

| Parent | Package | Use when |
|--------|---------|----------|
| `Swissup/breeze-blank` | `swissup/breeze-blank` | Minimal base; you build the look yourself. |
| `Swissup/breeze-evolution` | `swissup/breeze-evolution` | Feature-rich default — the usual choice. |
| `Swissup/breeze-enterprise` | `swissup/breeze-enterprise` | Premium feature set. |

Default to the parent that is actually installed (`theme.breeze.parent` /
`theme.breeze.packages` from `magento2-context`). Never reference a parent whose package is not
present — `setup:upgrade` will fail.

## `web/css/breeze/_default.less` and the `@critical` guard

Breeze compiles `web/css/breeze/_default.less` separately from Luma's `_extend.less` and inlines
the **critical** branch above the fold. Wrap above-the-fold rules in the `@critical` guard and
everything else in the inverse so deferred styles do not block first paint:

```less
& when (@critical) {
    .selector { /* inlined, above-the-fold */ }
}
& when not (@critical) {
    .selector:hover { /* deferred */ }
}
```

`web/css/source/_extend.less` stays as the standard Luma extension point so the theme still
degrades correctly on a blank/luma fallback render.

## The `breeze_default.xml` layout handle

Files named `breeze_*` (here `breeze_default.xml`) are loaded **only** on Breeze-based themes and
never affect blank/luma. Use this handle to register theme-level Breeze JS components on the
`breeze.js` block or to move blocks for the Breeze render. Do not set a `layout=""` attribute on
the `default` handle — it would force that layout site-wide.

## Activation

1. `bin/magento setup:upgrade`
2. `bin/magento setup:static-content:deploy -f`
3. **Content → Design → Configuration** → pick the store view → select the theme → Save
   (or `bin/magento config:set design/theme/theme_id <id>` then `cache:flush`).
