# Theme Patterns

Magento 2 themes inherit from a parent and override its assets.

## Luma Inheritance

```
Magento/blank → Magento/luma → {Vendor}/{theme}
```

A custom theme typically inherits from `Magento/luma`, overriding LESS variables and
specific templates.

```xml
<!-- theme.xml -->
<theme xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="urn:magento:framework:Config/etc/theme.xsd">
    <title>{Vendor} {Theme}</title>
    <parent>Magento/luma</parent>
</theme>
```

## Hyva Inheritance

Hyva is a Tailwind/Alpine-based replacement for Luma. Inherits from `Hyva/default`.

```xml
<theme xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="urn:magento:framework:Config/etc/theme.xsd">
    <title>{Vendor} Hyva</title>
    <parent>Hyva/default</parent>
</theme>
```

Key differences from Luma:
- No RequireJS
- No Knockout
- No jQuery in default bundle
- Tailwind CSS instead of LESS (per-theme)
- Alpine.js for interactivity

## Custom Theme

Ask the user for the parent theme. Default to `Magento/blank` for maximum flexibility,
or `Magento/luma` if the team wants full Luma features.

## File Layout

```
app/design/frontend/{Vendor}/{Theme}/
├── theme.xml
├── registration.php
├── composer.json
├── etc/
│   └── view.xml
├── Magento_Theme/
│   └── layout/
│       └── default.xml
├── web/
│   ├── css/
│   │   └── source/
│   │       ├── _theme.less
│   │       └── _extend.less
│   ├── fonts/
│   ├── images/
│   │   └── logo.svg
│   └── js/
└── media/
    └── preview.jpg
```

## Activating the Theme

```bash
{ctx.magento_cli} config:set design/theme/theme_id {Vendor}/{Theme}
{ctx.magento_cli} setup:static-content:deploy -f --theme={Vendor}/{Theme}
{ctx.magento_cli} cache:flush
```

## Theme Versions in composer.json

```json
{
    "name": "{vendor-lower}/theme-frontend-{theme-lower}",
    "type": "magento2-theme",
    "version": "1.0.0",
    "require": {
        "magento/framework": "^103.0",
        "magento/theme-frontend-luma": "^100.4"
    }
}
```

For Hyva: depend on `hyva-themes/magento2-default-theme`.

## Multi-Store Theme Assignment

```bash
{ctx.magento_cli} config:set design/theme/theme_id {Vendor}/{Theme} --scope=stores --scope-code=default
```

## Common Mistakes

- Forgetting `registration.php` — theme never registers, falls back silently to parent.
- Wrong `composer.json` `type` — must be `magento2-theme`, not `magento2-module`.
- Editing parent theme files instead of overriding in child — changes lost on update.
