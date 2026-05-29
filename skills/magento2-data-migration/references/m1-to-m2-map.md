# Magento 1 → 2 Map

Common transformations when migrating data from Magento 1 to Magento 2.

## Schema Differences

| M1 | M2 |
|----|----|
| `core_store` | `store` |
| `core_store_group` | `store_group` |
| `core_website` | `store_website` |
| `customer_entity` | `customer_entity` (compatible) |
| `customer_address_entity` | `customer_address_entity` (compatible) |
| `sales_flat_order` | `sales_order` |
| `sales_flat_order_item` | `sales_order_item` |
| `sales_flat_quote` | `quote` |
| `catalog_product_flat` | (removed; use indexer) |
| `catalog_category_flat_store_X` | (removed) |

## EAV Type IDs

EAV `entity_type_id` values are DB-assigned and may differ between M1 and M2. Always
look up by `entity_type_code` rather than hardcoded ID.

```sql
SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product';
```

## Status / Type Codes

| M1 | M2 |
|----|----|
| `processing`, `complete`, `pending` (order status) | Same in M2 |
| `simple`, `configurable`, `bundle`, `grouped`, `virtual`, `downloadable` (product type) | Same |
| `0/1` for status | Same (1=enabled, 2=disabled in M2; was 1=disabled, 2=enabled in some M1 variants — verify) |

## URL Rewrites

M1 stores URL rewrites in `core_url_rewrite`. M2 uses `url_rewrite` with a different
schema. Plan the migration:

```sql
INSERT INTO url_rewrite (entity_type, entity_id, request_path, target_path, redirect_type, store_id)
SELECT 'product', product_id, request_path, target_path, 0, store_id
FROM m1_database.core_url_rewrite
WHERE id_path LIKE 'product/%';
```

## Password Hashes

M1 used `md5(salt:password)`. M2 uses `argon2id` or `sha256` (configurable). Direct
migration of hashes is NOT possible — users must reset passwords, OR the M2 install
must support legacy hash format temporarily.

## Tax Rates

M1's `tax_calculation_rate` is mostly compatible with M2's `tax_calculation_rate`. The
class linking tables differ — verify foreign keys.

## Cron Jobs / Indexers

Do NOT migrate `cron_schedule` or indexer state. M2 regenerates these on its own.

## Suggested Migration Order

1. Stores, websites, groups
2. Customer groups
3. Tax rates and rules
4. Categories
5. Products (one product type at a time)
6. Customers
7. Customer addresses
8. Orders (most recent first; archive older)
9. URL rewrites
10. CMS pages and blocks

## Adobe Migration Tool

Adobe provides an official Data Migration Tool:

```
composer require magento/data-migration-tool
{ctx.magento_cli} migrate:settings <path-to-config>.xml
{ctx.magento_cli} migrate:data <path-to-config>.xml
```

For most migrations this is the right starting point. This skill complements it for
custom data not covered by the official tool.
