# Field Types & Form Elements

A `<field>` separates **`formElement`** (the widget) from **`dataType`** (the value type). Getting
this pair wrong is a common "field renders but won't bind" cause. ([S2], [S7])

## formElement → dataType map

| formElement | typical dataType | Notes |
|-------------|------------------|-------|
| `input` | `text` / `number` / `price` | single-line |
| `textarea` | `text` | multi-line plain |
| `select` | `text` / `int` | needs an options `<settings><options>` source class |
| `multiselect` | `text` | stores comma/array; usually needs a backend model |
| `checkbox` | `boolean` | single toggle — see below |
| `checkboxset` / `radioset` | `int`/`text` | grouped |
| `date` | `date` | date picker |
| `price` | `number` | currency adornment |
| `wysiwyg` | `text` | rich text — see uploaders-wysiwyg.md |
| `fileUploader` / `imageUploader` | `text` | needs an upload controller — see uploaders-wysiwyg.md |
| `dynamicRows` | — | repeatable rows — see below |

## Boolean toggle (canonical)

```xml
<field name="is_active" formElement="checkbox">
    <argument name="data" xsi:type="array">
        <item name="config" xsi:type="array"><item name="source" xsi:type="string">{entity}</item></item>
    </argument>
    <settings><dataType>boolean</dataType><label translate="true">Enable</label></settings>
    <formElements>
        <checkbox>
            <settings>
                <valueMap><map name="false" xsi:type="string">0</map><map name="true" xsi:type="string">1</map></valueMap>
                <prefer>toggle</prefer>
            </settings>
        </checkbox>
    </formElements>
</field>
```

`<prefer>toggle</prefer>` renders the switch; `valueMap` maps the boolean to the stored `0`/`1`.

## Select with options

Point `formElement="select"` at a source via `<settings><options class="…\Model\Source\…"/></settings>`
(an `OptionSourceInterface`/`ArrayInterface` returning `[['value'=>…,'label'=>…]]`).

## dynamicRows (repeatable rows)

`dynamicRows` + `dynamicRows-record` render a one-to-many "grid in the form"; records map to an
**indexed array** under the field name, with a `recordTemplate` defining one row. The most common bug
is supplying an associative (not indexed) array → empty grid. ([S13], [S14], pitfalls.md)

## Sources
- [S2] Adobe — UI components overview: https://developer.adobe.com/commerce/frontend-core/ui-components/
- [S7] Adobe — Custom product creation form: https://developer.adobe.com/commerce/php/tutorials/admin/custom-product-creation-form/
- [S13] Adobe — Dynamic-rows record: https://developer.adobe.com/commerce/frontend-core/ui-components/components/dynamic-rows-record
- [S14] BSS Commerce — dynamic rows: https://bsscommerce.com/magento/blog/use-magento-2-dynamic-rows/
