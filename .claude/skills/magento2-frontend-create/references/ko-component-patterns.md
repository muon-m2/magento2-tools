# Knockout / UI Component Patterns

Magento 2 ships two flavors of KO components:
- **UI component** — extends `uiComponent`, integrated with the UI component layout XML.
- **KO-only** — bare KO viewmodel; manual wiring.

## UI Component (Preferred)

### Component class

```js
define([
    'uiComponent',
    'ko',
    'mage/translate',
], function (Component, ko, $t) {
    'use strict';

    return Component.extend({
        defaults: {
            template: '{Vendor}_{Module}/view/my-component',
            label: ''
        },

        initObservable: function () {
            this._super().observe(['label']);
            return this;
        },

        setLabel: function (text) {
            this.label(text);
        }
    });
});
```

### Template

```html
<!-- view/frontend/web/template/view/my-component.html -->
<div class="my-component">
    <h2 data-bind="text: label"></h2>
</div>
```

### Layout wiring

```xml
<referenceContainer name="content">
    <block name="my.component" class="Magento\Framework\View\Element\Template"
           template="{Vendor}_{Module}::content/component.phtml">
        <arguments>
            <argument name="jsLayout" xsi:type="array">
                <item name="components" xsi:type="array">
                    <item name="my-component" xsi:type="array">
                        <item name="component" xsi:type="string">{Vendor}_{Module}/js/view/my-component</item>
                        <item name="label" xsi:type="string" translate="true">Hello</item>
                    </item>
                </item>
            </argument>
        </arguments>
    </block>
</referenceContainer>
```

### Template wrapper

```html
<!-- content/component.phtml -->
<div data-bind="scope: 'my-component'">
    <!-- ko template: getTemplate() --><!-- /ko -->
</div>
<script type="text/x-magento-init">
{
    "*": { "Magento_Ui/js/core/app": <?= /* @noEscape */ $block->getJsLayout() ?> }
}
</script>
```

## KO-Only Component

For simple bindings without UI component overhead:

```html
<div data-bind="...">...</div>

<script>
require(['ko'], function (ko) {
    ko.applyBindings({label: ko.observable('Hello')}, document.getElementById('target'));
});
</script>
```

Rarely needed in modern Magento — prefer UI components.

## Performance

- Don't initialize KO bindings on the entire page — scope to a specific element.
- For large lists, use `foreach` virtual binding (don't render N times).
- Avoid `computed` observables in templates — they re-run on every dependency change.

## Hyva Note

Hyva theme does NOT run Knockout. If `{ctx.theme.frontend} == 'hyva'`, the skill
generates Alpine.js components instead.
