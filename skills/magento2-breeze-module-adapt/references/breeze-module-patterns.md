# Breeze Module Adapter Patterns

Reference for `magento2-breeze-module-adapt`. Source: https://breezefront.com/docs/custom-module

## Why a separate companion module

The adapter lives in a new `{Vendor}_{Module}Breeze` module, never inside the target. This:

- works when the target is in read-only `vendor/`,
- survives target upgrades,
- keeps Breeze-only code isolated and easy to remove.

`etc/module.xml` must declare a `<sequence>` on both the target and `Swissup_Breeze` so the
adapter's layout, CSS, and JS load after them:

```xml
<module name="{Vendor}_{Module}Breeze">
    <sequence>
        <module name="{Vendor}_{Module}"/>
        <module name="Swissup_Breeze"/>
    </sequence>
</module>
```

## The `breeze_` layout rule

Layout files named `breeze_*` (e.g. `breeze_default.xml`, `breeze_catalog_product_view.xml`,
`breeze_checkout.xml`) apply **only** to Breeze-based themes and never change a blank/luma render.
This is how the adapter registers JS without affecting non-Breeze stores.

## CSS: `web/css/breeze/_default.less`

Breeze auto-includes `<module>/view/frontend/web/css/breeze/_default.less` on every page. Use the
`@critical` guard so above-the-fold rules are inlined and the rest is deferred:

```less
& when (@critical) { .selector { /* inlined */ } }
& when not (@critical) { .selector:hover { /* deferred */ } }
```

For checkout-only styles use `_checkout.less`; for email use `_email.less` with the
`.email-non-inline()` mixin.

## JS registration on the `breeze.js` block

Two routes, chosen per module (see `breeze-js-conversion.md`):

1. **Port to a Breeze widget** — register the component so Breeze loads your Cash `$.widget`:
   ```xml
   <referenceBlock name="breeze.js">
       <arguments>
           <argument name="components" xsi:type="array">
               <item name="{vendor_lower}_{module_lower}" xsi:type="array">
                   <item name="component" xsi:type="string">{Vendor}_{Module}Breeze/js/breeze/widget</item>
               </item>
           </argument>
       </arguments>
   </referenceBlock>
   ```

2. **Better Compatibility** — keep the module's existing RequireJS and let Breeze load it:
   ```xml
   <argument name="better_compatibility" xsi:type="array">
       <item name="{Vendor}_{Module}" xsi:type="boolean">true</item>
   </argument>
   ```

Prefer (2) for large or rarely-touched modules; prefer (1) for hot-path widgets where the extra
RequireJS payload hurts performance.
