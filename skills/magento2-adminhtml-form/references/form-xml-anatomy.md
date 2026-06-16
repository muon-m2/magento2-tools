# Form XML Anatomy & the Naming Contract

The admin form is a declarative UI component at
`{Vendor}/{Module}/view/adminhtml/ui_component/{entity}_form.xml`, root element `<form>`, bound to
`urn:magento:module:Magento_Ui:etc/ui_configuration.xsd`. It is rendered by a layout that includes
`<uiComponent name="{entity}_form"/>`. ([S1], [S7])

> Adobe's Form doc shows `view/base/ui_component/customer_form.xml` because the customer form is
> area-shared. For a normal admin form, use **`view/adminhtml/ui_component/`**.

## The naming contract (prevents the blank form)

These five names MUST agree. A single mismatch renders an empty form with **no error** — the #1
time-sink for new developers. ([S16], pitfalls.md)

| # | Where | Value |
|---|-------|-------|
| 1 | `<namespace>` + file name | `{entity}_form` |
| 2 | `js_config` → `provider` | `{entity}_form.{entity}_form_data_source` |
| 3 | `<dataSource name>` | `{entity}_form_data_source` |
| 4 | `<dataProvider name>` | `{entity}_form_data_source` |
| 5 | layout `<uiComponent name>` | `{entity}_form` |

The convention: dataSource name = `{form namespace}_data_source`; provider = `{namespace}.{dataSource name}`.

## Skeleton

```
<form>
  <argument name="data">          ← js_config.provider, label, template (form/collapsible)
  <settings>
    <buttons>                     ← one <button> per Block button class (see controllers-and-routing.md)
    <namespace>{entity}_form</namespace>
    <dataScope>data</dataScope>
    <deps><dep>…_data_source</dep></deps>
  <dataSource name="…_data_source" component="Magento_Ui/js/form/provider">
    <settings><submitUrl path="{vendor_lower}_{entity}/{entity}/save"/></settings>
    <dataProvider class="…\Model\{Entity}\DataProvider" name="…_data_source">
      <settings>
        <requestFieldName>{entity}_id</requestFieldName>   ← which request param selects the record
        <primaryFieldName>{entity}_id</primaryFieldName>   ← the entity id column
  <fieldset name="general">       ← fieldsets nest; contain <field> elements
    <field name="…" formElement="…">  ← see field-types.md
```

`<requestFieldName>` and `<primaryFieldName>` ARE valid direct children of the `<dataProvider>`
`<settings>` node (resolves a common XSD doubt). ([S1])

## Cross-module merge

`ui_component/*_form.xml` files are **merged across modules** by file name, so an extension declares
only its delta — it never copies the whole form. This is why the declarative approach replaces the
legacy `Block\Widget\Form`. ([S7])

## The `source` item

Each field's `<item name="source">{entity}</item>` is an entity-grouping label (mirrors CMS's
`source=block`/`page`). It does **not** by itself cause blank fields — the blank-form cause is the
naming contract and the `getData()` shape, not `source`. See dataprovider-patterns.md.

## Sources
- [S1] Adobe — Form component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/form/
- [S7] Adobe — Custom product creation form: https://developer.adobe.com/commerce/php/tutorials/admin/custom-product-creation-form/
- [S16] magento2 issue #22859: https://github.com/magento/magento2/issues/22859
