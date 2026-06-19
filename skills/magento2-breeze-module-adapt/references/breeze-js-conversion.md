# Converting Module JS to Breeze

Reference for `magento2-breeze-module-adapt`. Breeze ships [Cash](https://github.com/fabiospampinato/cash)
(a small jQuery-compatible library) and its own `$.widget` factory instead of RequireJS + jQuery UI
+ Knockout. Source: https://breezefront.com/docs/custom-module

## Decision: port vs. Better Compatibility

| Target JS pattern | Recommended route |
|-------------------|-------------------|
| Small jQuery-UI `$.widget` on a hot path (PDP, cart) | **Port** to a Breeze `$.widget` |
| Plain `data-mage-init` / `text/x-magento-init` calling a simple module | Often works as-is; verify |
| Heavy Knockout `uiComponent` (e.g. checkout) | **Better Compatibility** (Breeze has no KO) |
| Large/legacy module you don't want to maintain | **Better Compatibility** |
| RequireJS `mixins` over core widgets | **Better Compatibility** (then test) |

## The Breeze widget shape

```js
$.widget('uniqueName', {
    component: '{Vendor}_{Module}/js/breeze/widget',

    create: function () {
        // this.element — Cash collection for the bound node
        // this.options — JSON config from data-mage-init / x-magento-init
    }
});
```

- The first argument is a unique widget name; `component` is the asset path Breeze resolves.
- Breeze honors standard `data-mage-init` and `text/x-magento-init` instructions, so the markup
  that triggered the Luma widget usually triggers the Breeze widget unchanged.

## Mapping reference

| Luma / RequireJS | Breeze equivalent |
|------------------|-------------------|
| `define(['jquery'], function ($) {...})` | drop the AMD wrapper; `$` (Cash) is global |
| `$.widget('vendor.name', {_create: …})` | `$.widget('name', {create: …})` |
| `$(el).on('click', …)` | same (Cash supports it) |
| `ko.observable` / KO bindings | rewrite as plain DOM + Cash, or use Better Compatibility |
| `$.ajax({...}).done(…)` | `$.ajax` exists in Breeze but prefer `fetch`; avoid jQuery `Deferred` chains |
| `$(el).animate(…)` | not in Cash core — use CSS transitions or a Breeze helper |

## Cash gaps to watch

Cash is not 100% jQuery. Common missing/different APIs: `$.Deferred`, `.animate()`, some
`$.fn` plugins, and effect methods. When a port hits one of these, either rewrite with native
APIs/CSS or fall back to Better Compatibility for that module.
