# Grid Collection (SearchResult path)

The optional SearchResult path replaces the default PHP `DataProvider` class with a `di.xml`
virtual-type collection. Use it when the grid needs SQL JOINs or when you want to decouple the
grid collection entirely from the entity's standard collection.

## When to use

- The grid needs to display columns from a related table (e.g. join a `store` table or a
  `category` relation).
- The main entity table is large and you want custom index-based loading.
- The grid is used independently across modules and the `di.xml` wiring is cleaner than
  injecting a specialised DataProvider everywhere.

For a simple single-table grid, use the default `AbstractDataProvider` path instead (see
`references/dataprovider-wiring.md`).

## The di.xml wiring

`templates/di-listing.xml` emits:

```xml
<type name="Magento\Framework\View\Element\UiComponent\DataProvider\CollectionFactory">
    <arguments>
        <argument name="collections" xsi:type="array">
            <item name="{SOURCE}" xsi:type="string">
                {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid\Collection
            </item>
        </argument>
    </arguments>
</type>
<virtualType name="{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid\Collection"
             type="Magento\Framework\View\Element\UiComponent\DataProvider\SearchResult">
    <arguments>
        <argument name="mainTable" xsi:type="string">{vendor_lower}_{module_lower}_{entity}</argument>
        <argument name="resourceModel" xsi:type="string">{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}</argument>
    </arguments>
</virtualType>
```

The `item name` (the map key) MUST equal `{SOURCE}` (`{vendor_lower}_{module_lower}_{entity}_listing_data_source`) exactly. A one-character mismatch causes a silent empty grid because the `CollectionFactory` cannot find the mapping. See `references/listing-xml-anatomy.md`.

When using this path, swap `listing.xml`'s inner `<dataProvider class>` to
`Magento\Framework\View\Element\UiComponent\DataProvider\DataProvider` (the generic one) — the
di map handles the collection resolution.

## Grid\Collection (concrete PHP class)

Use a concrete PHP class (see `templates/grid-collection.php`) instead of the virtualType when
you need joins or custom `_initSelect` logic that cannot be expressed in XML:

```php
namespace {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid;

use Magento\Framework\View\Element\UiComponent\DataProvider\SearchResult;

class Collection extends SearchResult
{
    protected function _initSelect(): void
    {
        parent::_initSelect();
        // Example: join a related table
        $this->getSelect()->joinLeft(
            ['rel' => $this->getTable('related_table')],
            'main_table.rel_id = rel.id',
            ['rel_name' => 'rel.name']
        );
    }
}
```

Replace the virtualType's `xsi:type="string"` value with the fully-qualified class name of the
concrete class, and reference it identically in the `CollectionFactory.collections` map.

## mainTable and resourceModel

- `mainTable` — the bare database table name without prefix (e.g. `acme_faq_faq`). Magento
  prepends the `tablePrefix` automatically via `getTable()`.
- `resourceModel` — the entity's `ResourceModel` class (e.g.
  `Acme\Faq\Model\ResourceModel\Faq`). `SearchResult` uses it to derive the primary key
  column via `getIdFieldName()`.

## Sources
- [S3] Adobe — DataProvider for UI grid: https://developer.adobe.com/commerce/frontend-core/ui-components/concepts/data-provider/
- [S7] Adobe — SearchResult class: https://developer.adobe.com/commerce/php/development/components/ui-components/data-providers/
