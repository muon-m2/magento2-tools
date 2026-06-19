# Mview Subscriptions

Reference for `mview.xml` structure, how subscriptions wire the source table to partial
reindex, and how to choose the right table and entity column.

## mview.xml structure

Location: `{Vendor}/{Module}/etc/mview.xml` — merged with other modules' declarations.

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:Mview/etc/mview.xsd">
    <view id="{indexer_id}"
          class="{Vendor}\{Module}\Model\Indexer\{IndexerName}"
          group="indexer">
        <subscriptions>
            <table name="{source_table}" entity_column="{id_column}"/>
        </subscriptions>
    </view>
</config>
```

Key attributes:
- `id` — **must equal** the `id` attribute on `<indexer>` in `indexer.xml`. This is the
  single most common mview misconfiguration.
- `class` — same FQCN as `indexer.xml`; must implement
  `Magento\Framework\Mview\ActionInterface`.
- `group` — always `indexer` for standard indexer subscriptions.

### `<table>` subscription

| Attribute | Meaning | Example |
|-----------|---------|---------|
| `name` | Source DB table to watch for INSERT/UPDATE/DELETE | `cataloginventory_stock_item` |
| `entity_column` | Column in `name` that holds the entity primary key | `product_id` |

Multiple `<table>` elements are allowed when the entity spans more than one table.

## How subscriptions trigger partial reindex

1. A save operation (admin or API) writes to `{source_table}`.
2. Magento's mview observers record the affected `{id_column}` values in a generated
   changelog table (`mview_{indexer_id}_cl`).
3. When the indexer is in **schedule** mode, the cron group `indexer` drains the changelog
   table and calls `execute($ids)` on the indexer class with the batched id list.
4. In **realtime** mode the changelog table is still written but never drained — Magento
   instead calls `executeRow($id)` / `executeList($ids)` synchronously after the save.

## Choosing the source table and entity_column

- Use the **lowest-level source-of-truth** table, not a joined/view table.
- `entity_column` must be a column that uniquely identifies the **indexed entity** — not
  a foreign key to a parent entity unless that is what you intend to reindex.
- If the entity's data comes from multiple tables, add one `<table>` subscription per
  source. Each subscription's `entity_column` must resolve to the same entity id space
  (the same type of id the action class accepts).

## The `indexer` mview group

The `group="indexer"` attribute places the mview change-log processing under Magento's
built-in indexer cron schedule. You do not need to declare a separate cron job.
Custom groups are possible but not recommended for standard indexers.
