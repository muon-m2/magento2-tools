# RequireJS Patterns

## Module Definition

```js
define([
    'jquery',
    'underscore',
    'mage/translate',
], function ($, _, $t) {
    'use strict';

    return function (config, element) {
        var instance = {
            config: config,
            element: element,
            init: function () { /* ... */ },
        };
        instance.init();
        return instance;
    };
});
```

## Registration in `requirejs-config.js`

```js
var config = {
    map: {
        '*': {
            'myModule': '{Vendor}_{Module}/js/my-module'
        }
    }
};
```

The skill MERGES with existing `requirejs-config.js` rather than overwriting.

## Layout Activation

```xml
<referenceBlock name="page.wrapper">
    <block class="Magento\Framework\View\Element\Template" template="{Vendor}_{Module}::component.phtml"/>
</referenceBlock>
```

In the template:

```html
<div data-mage-init='{"myModule": {"option": "value"}}'></div>
```

Or use `x-magento-init`:

```html
<script type="text/x-magento-init">
{
    ".my-selector": {
        "myModule": {"option": "value"}
    }
}
</script>
```

## Mixins

For modifying core RequireJS modules without overriding:

```js
// view/frontend/requirejs-config.js
var config = {
    config: {
        mixins: {
            'Magento_Checkout/js/view/summary': {
                '{Vendor}_{Module}/js/view/summary-mixin': true
            }
        }
    }
};
```

```js
// view/frontend/web/js/view/summary-mixin.js
define([], function () {
    'use strict';
    return function (target) {
        return target.extend({
            myCustomMethod: function () { /* ... */ }
        });
    };
});
```

## Common Mistakes

- Forgetting `'use strict'` — Magento style.
- Not returning the public API from the factory — module exports nothing.
- Hard-coupling to jQuery in Hyva theme — Hyva doesn't bundle jQuery.
