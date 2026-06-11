# Frontend Impact

Attribute flags that affect storefront and admin behaviour beyond just "is the value
visible."

## Catalog Search

| Flag                              | Effect                                            |
|-----------------------------------|---------------------------------------------------|
| `is_searchable=1`                 | Attribute value indexed in catalogsearch_fulltext |
| `is_visible_in_advanced_search=1` | Appears in Advanced Search form                   |
| `search_weight`                   | Weight in fulltext relevance scoring (1-10)       |

After enabling: reindex `catalogsearch_fulltext`.

## Layered Navigation

| Flag                        | Effect                                     |
|-----------------------------|--------------------------------------------|
| `is_filterable=1`           | Layered nav shows filter on category pages |
| `is_filterable_in_search=1` | Layered nav on search results              |
| `position`                  | Order of filter in layered nav             |

After enabling: reindex `catalog_product_eav` + flush layout cache.

## Sorting

| Flag                 | Effect                          |
|----------------------|---------------------------------|
| `used_for_sort_by=1` | Available in "Sort By" dropdown |

## Listing

| Flag                        | Effect                                                      |
|-----------------------------|-------------------------------------------------------------|
| `used_in_product_listing=1` | Pre-loaded with the catalog listing collection (avoids N+1) |
| `is_visible_on_front=1`     | Displayed on the product detail page                        |

`used_in_product_listing` is critical for performance — if `false`, accessing the
attribute in a category page triggers a per-product load (N+1).

## Admin Grid (Customer)

For customer attributes:

| Flag                      | Effect                                  |
|---------------------------|-----------------------------------------|
| `is_used_in_grid=1`       | Column available in admin customer grid |
| `is_visible_in_grid=1`    | Column shown by default                 |
| `is_filterable_in_grid=1` | Searchable from grid filter             |
| `is_searchable_in_grid=1` | Included in quick search                |

## Required Reindex / Flush After Adding

| Flag                      | Reindex / cache flush                                |
|---------------------------|------------------------------------------------------|
| `is_searchable`           | `bin/magento indexer:reindex catalogsearch_fulltext` |
| `is_filterable`           | `bin/magento indexer:reindex catalog_product_eav`    |
| `used_in_product_listing` | Flush layout + block cache                           |
| Any visibility change     | Flush layout + block cache                           |

The skill's Phase 5 report includes the relevant reindex command for each flag set.

## Product Forms / Attribute Sets

Default attribute set: `Default` (ID `4` for Magento sample data).

When the new attribute should be in the default set:

```php
$eavSetup->addAttributeToGroup(
    \Magento\Catalog\Model\Product::ENTITY,
    'Default',                  // attribute set name
    'General',                  // group name
    'acme_color',               // attribute code
    50                          // sort order
);
```

For a custom attribute set, replace `'Default'` with the set name.

## Common Mistake

Forgetting `used_in_product_listing` when the attribute is shown on listings causes a
per-product attribute load → N+1 → slow listings at scale. Always set it `true` when
the attribute appears on storefront listings.

## API Visibility

Attributes with `is_used_in_grid=1` are exposed in customer REST/GraphQL automatically.
Attributes without `is_visible_on_front` are still queryable via REST — admin scope
endpoints don't filter on visibility flags.
