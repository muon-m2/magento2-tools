# Indexer Health

## Modes

| Mode | Behaviour | When to use |
|------|-----------|-------------|
| `realtime` (Update on Save) | Reindex synchronously on save | Dev only |
| `schedule` (Update on Schedule) | Cron-based batch reindex | Production default |

Production runs with `schedule` mode. A finding fires if any indexer is in `realtime` in
production:

```
{ctx.magento_cli} indexer:show-mode
```

## Status

```
{ctx.magento_cli} indexer:status
```

States:
- `Ready` — index is current
- `Reindex Required` — schema or config changed; full reindex needed
- `Working` — currently rebuilding

A finding fires when any indexer has been in `Reindex Required` for > 1 hour with cron
active (cron should have caught it).

## Performance Indexers

| Indexer | Purpose | Typical reindex time (10K SKUs) |
|---------|---------|-------------------------------|
| catalog_product_attribute | Searchable attributes | ~30s |
| catalogsearch_fulltext | Catalog search index | ~2min |
| cataloginventory_stock | Stock status | ~30s |
| catalog_category_product | Category-product mapping | ~1min |
| catalogrule_product | Catalog price rules | ~1min |
| customer_grid | Admin customer grid | ~10s |

Reindex times scale super-linearly past ~50K SKUs. A finding fires if cron is failing
to keep indexers current at scale.

## Custom Indexers

Custom indexers in custom modules should:
- Implement `Magento\Framework\Indexer\ActionInterface`
- Register in `etc/indexer.xml`
- Support both full and partial reindex
- Batch process (do not load full collection)

A finding fires when a custom indexer uses `getCollection()->getItems()` without
`setPageSize` — that will OOM at scale.

## Reindex Cron Schedule

By default `indexer_reindex_all_invalid` runs every minute. Custom indexers may have
their own schedule — check `etc/crontab.xml` for `<group id="index">`.

## Recommended Findings

| Pattern | Severity |
|---------|---------|
| Indexer in realtime mode (production) | Medium |
| Indexer stuck in "Reindex Required" > 1h | High |
| Custom indexer without batch processing | High |
| Indexer cron group not registered | Medium |

## Runtime Probe Output

```json
{
  "indexers": [
    {"id": "catalog_category_product", "status": "Ready", "mode": "schedule"},
    {"id": "cataloginventory_stock", "status": "Reindex Required", "mode": "realtime"}
  ]
}
```
