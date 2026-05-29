# Static Asset Rules

## Asset Locations

```
{Vendor}/{Module}/view/{area}/web/
├── css/
├── fonts/
├── images/
├── js/
└── template/
```

`{area}` is one of: `frontend`, `adminhtml`, `base`.

## Fallback Chain

Magento resolves static assets via:
1. Current theme `app/design/{area}/{Vendor}/{Theme}/{Module}/web/`
2. Parent theme(s) — walk up `<parent>` declarations
3. Module's `view/{area}/web/`
4. Module's `view/base/web/`

The closest match wins.

## Referencing in Layout / Template

```xml
<link src="{Vendor}_{Module}::css/extras.css"/>
<script src="{Vendor}_{Module}::js/page.js"/>
```

Or in `.phtml`:

```php
<img src="<?= $block->escapeUrl($block->getViewFileUrl('{Vendor}_{Module}::images/logo.svg')) ?>" alt="Logo"/>
```

## Publishing Static Content

In `default` and `developer` modes, assets are served from `pub/static/` symlinked to
the source on first request.

In `production` mode, run:

```bash
{ctx.magento_cli} setup:static-content:deploy -f --theme={Vendor}/{Theme}
```

This copies all assets to `pub/static/version{N}/...`. The version is incremented on
every deploy.

## Cache Busting

Magento appends the version to asset URLs automatically. No manual cache busting needed
when running `setup:static-content:deploy`.

## Image Optimization

Magento does NOT auto-optimize images. For best performance:
- Use SVG where possible
- Pre-optimize PNG/JPG before commit (use `imagemin` or similar)
- Serve WebP via a CDN that auto-converts

## Font Loading

```less
@font-face {
    font-family: 'CustomFont';
    src: url('@{baseDir}fonts/CustomFont.woff2') format('woff2');
    font-weight: 400;
    font-display: swap;
}
```

`@{baseDir}` is Magento's LESS variable for the theme's web/ directory.

## Common Mistakes

- Hardcoded paths like `/static/...` — break in version-prefixed deploys.
- Referencing assets by absolute filesystem path in PHP — won't resolve through fallback chain.
- Forgetting `setup:static-content:deploy` after asset change in production mode — old asset still served.
