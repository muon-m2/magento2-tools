# LESS / CSS Rules

## Magento 2 LESS Structure (Luma)

```
web/css/source/
├── _theme.less          # Variable overrides (colors, fonts, breakpoints)
├── _extend.less         # Additional rules on top of Luma
└── _module.less         # Module-specific styles (auto-imported)
```

`_module.less` in each module's `view/frontend/web/css/source/` is auto-imported by
Magento's LESS compiler.

## Variable Override Pattern

```less
// _theme.less
@color-primary: #1a73e8;
@color-secondary: #fbbc04;
@font-family-name__base: 'Inter', sans-serif;
```

These override Luma's defaults at compile time.

## Module LESS

```less
// {Vendor}_{Module}/view/frontend/web/css/source/_module.less
.{vendor-lower}-{module-lower} {
    &__header { color: @color-primary; }
    &__cta {
        background: @color-primary;
        color: @color-white;
        padding: 8px 16px;
        &:hover { background: darken(@color-primary, 10%); }
    }
}
```

BEM-style naming avoids conflicts with other modules.

## Compilation

```bash
{ctx.magento_cli} setup:static-content:deploy -f
```

In `developer` mode, LESS is compiled on demand (slow first load).

## Hyva (Tailwind)

Hyva does not use LESS. Custom styles go in `view/frontend/tailwind/tailwind-source.css`
using `@apply`:

```css
.{vendor-lower}-{module-lower}-cta {
    @apply bg-primary text-white px-4 py-2 rounded hover:bg-primary-darker;
}
```

Then run `npm run build` in the theme directory to compile Tailwind.

## Common Mistakes

- Editing LESS variables in Luma's `vendor/magento/theme-frontend-luma/web/css/source/_theme.less`
  directly — changes lost on update. Always override in the child theme.
- Forgetting to redeploy static content after LESS changes (production mode).
- Mixing LESS and SCSS in the same theme — Magento expects one or the other.
