# Modifier & Pool Pattern (optional surface)

Modifiers let you change a form's **data** and **metadata** in PHP at runtime. They are the canonical
way to *extend an existing* core form (product, customer) or to build fields dynamically. For a new
simple form, prefer the modifier-less DataProvider — the modifier is an **optional surface**.

## ModifierInterface

A modifier implements `Magento\Ui\DataProvider\Modifier\ModifierInterface` with two methods, each
taking and returning an array ([S3], [S6]):

```php
public function modifyData(array $data): array;   // values, keyed by entity id
public function modifyMeta(array $meta): array;    // structure: fields, fieldsets, labels, visibility
```

It may instead extend `Magento\Catalog\Ui\DataProvider\Product\Form\Modifier\AbstractModifier`
(catalog helpers). At runtime the modifier-produced structure is **merged** with the `form.xml`
declaration — XML and modifiers compose. ([S3])

## Pool wiring

Register modifiers in a `Magento\Ui\DataProvider\Modifier\Pool` **virtualType** in
`etc/adminhtml/di.xml`; each entry has a `class` and a numeric `sortOrder` (execution order). Inject
the pool into the DataProvider. ([S3], [S6]) — see `templates/di-modifier-pool.xml`.

```xml
<type name="{Vendor}\{Module}\Model\{Entity}\DataProvider">
    <arguments><argument name="pool" xsi:type="object">…FormModifierPool</argument></arguments>
</type>
<virtualType name="…FormModifierPool" type="Magento\Ui\DataProvider\Modifier\Pool">
    <arguments><argument name="modifiers" xsi:type="array">
        <item name="{entity}_modifier" xsi:type="array">
            <item name="class" xsi:type="string">…\{Entity}Modifier</item>
            <item name="sortOrder" xsi:type="string">10</item>
        </item>
    </argument></arguments>
</virtualType>
```

## When you add a modifier, switch the base class

The DataProvider must extend `Magento\Ui\DataProvider\ModifierPoolDataProvider` (not
`AbstractDataProvider`) so the `pool` argument is accepted and `getMeta()` runs the modifiers. Loop
`getModifiersInstances()` and call `modifyData()` inside `getData()` for the data side. ([S8])

## Gotcha: sortOrder collisions

Two modifiers with the same `sortOrder` run in an undefined order — a real source of "field appears
then disappears" bugs. Keep them distinct. (pitfalls.md)

## Sources
- [S3] Adobe — Modifier concept: https://developer.adobe.com/commerce/frontend-core/ui-components/concepts/modifier/
- [S6] Adobe — Modifier class tutorial: https://developer.adobe.com/commerce/php/tutorials/admin/custom-product-creation-form/modifier-class/
- [S8] Smile-SA seller DataProvider: https://github.com/Smile-SA/magento2-module-seller/blob/master/Ui/Component/Seller/Form/DataProvider.php
