# DataProvider Wiring

The listing's `<dataSource>` references a class implementing
`Magento\Framework\View\Element\UiComponent\DataProvider\DataProviderInterface`. There are two
supported wiring paths; choose based on whether the grid needs joins or is expected to grow large.

## Default path — `AbstractDataProvider` + `CollectionFactory`

```
listing.xml  →  <dataProvider class="{Vendor}\…\Ui\DataProvider\{EntityName}DataProvider">
PHP          →  class {EntityName}DataProvider extends AbstractDataProvider
di.xml       →  (none required)
```

Use this path unless you need joins or advanced filtering. Advantages:

- No `di.xml` entry required — the class is wired directly in `listing.xml`.
- `AbstractDataProvider::getData()` already returns the grid shape:
  `['items' => [...], 'totalRecords' => N]`. Do **not** override `getData()` for the listing.
- The `CollectionFactory` is injected in the constructor; `$this->collection` is assigned once.

See `templates/data-provider.php`.

### The empty-grid pitfall

The most common cause of an empty grid (when the data exists) is a **name mismatch** between the
five locations in `listing.xml` (see `references/listing-xml-anatomy.md`). The DataProvider class
itself is correct; the mismatch is in the XML. Run `scripts/verify-listing.sh` to confirm all
five places agree.

### Constructor signature

`AbstractDataProvider` constructor: `($name, $primaryFieldName, $requestFieldName, $meta, $data)`.
These five arguments are injected by the framework from the `<dataProvider>` XML settings. Assign
`$this->collection` before `parent::__construct()`. Example:

```php
public function __construct(
    string $name,
    string $primaryFieldName,
    string $requestFieldName,
    CollectionFactory $collectionFactory,
    array $meta = [],
    array $data = []
) {
    parent::__construct($name, $primaryFieldName, $requestFieldName, $meta, $data);
    $this->collection = $collectionFactory->create();
}
```

## Optional path — generic `DataProvider` + `SearchResult` + `di.xml` map

```
listing.xml  →  <dataProvider class="Magento\Framework\View\Element\UiComponent\DataProvider\DataProvider">
di.xml       →  CollectionFactory.collections["{SOURCE}"] = …\Grid\Collection
               virtualType …\Grid\Collection type=SearchResult (mainTable, resourceModel)
PHP          →  class Collection extends SearchResult  (only if joins are needed)
```

Use this path when:

- The grid needs SQL JOINs to display data from related tables.
- The table is very large and needs custom index-based loading.
- You want to add non-collection filters at the DB level.

### When to use which

| Situation | Path |
|-----------|------|
| Simple grid, single table | Default (`AbstractDataProvider`) |
| Grid with joined columns | SearchResult + `di.xml` |
| Large table, performance-sensitive | SearchResult + `di.xml` |
| Extending an existing grid | Default (merge listing XML only) |

### di.xml map key agreement

On the optional path the `di.xml` map key MUST equal `{SOURCE}` (`{vendor_lower}_{module_lower}_{entity}_listing_data_source`) byte-for-byte. A mismatch produces the same empty-grid symptom as the five-place naming contract failure — but the source is the di.xml, not the listing XML.

See `templates/di-listing.xml` and `references/grid-collection.md`.

## Sources
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
- [S3] Adobe — DataProvider for UI grid: https://developer.adobe.com/commerce/frontend-core/ui-components/concepts/data-provider/
