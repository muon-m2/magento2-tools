# Indexer Pitfalls

Common mistakes and how to avoid them when scaffolding a custom indexer.

## 1. `view_id` / `id` mismatch

The `view_id` attribute in `indexer.xml` must equal the `id` attribute in `mview.xml`.
A mismatch means scheduled partial reindex never fires — full reindex still works, so the
bug is invisible until load testing or changelog inspection.

Verify: `SELECT * FROM mview_state WHERE view_id = '{indexer_id}';` — if empty after
enabling schedule mode, the id is wrong.

## 2. Reindex logic in the indexer class

The indexer class (`{IndexerName}`) must be a pure dispatcher. Any SQL, collection load,
or data transformation in `executeFull` / `executeList` / `executeRow` / `execute` is a
bug. Move it to `{IndexerName}Action`. This keeps the indexer class easily testable with
a simple mock assertion.

## 3. Loading all ids at once (missing batching)

`executeList(array $ids)` and `execute(array $ids)` can receive thousands of ids during
a bulk operation. Loading all of them into memory at once causes OOM errors.

Always chunk:
```php
foreach (array_chunk($ids, self::BATCH_SIZE) as $batch) {
    $this->reindexBatch($batch);
}
```
Make `BATCH_SIZE` a class constant so operators can tune it via preference/DI.

## 4. Non-idempotent full reindex

`executeFull()` must be safe to call twice and yield identical results. The standard
pattern is:

1. Truncate (or delete-then-insert) the target index table.
2. SELECT all source data in paginated keyset batches.
3. INSERT the computed index rows.

Avoid UPDATE-only patterns — a stale row from a previous run can survive if the entity
was deleted upstream.

## 5. Heavy work in `executeRow`

`executeRow($id)` is called synchronously on every admin save in realtime mode. If it
triggers expensive JOINs or external HTTP calls, it will block the admin response.
Keep `executeRow` lightweight — compute only what changed for that single id — or
recommend `schedule` mode for expensive indexes.

## 6. Realtime vs schedule mode confusion

Realtime mode (`Update on Save`) calls `executeRow`/`executeList` synchronously.
Schedule mode (`Update by Schedule`) drains the mview changelog via cron and calls
`execute($ids)`.

Both paths must work. Do not assume one mode. Run:
```bash
bin/magento indexer:set-mode schedule {indexer_id}  # recommended for production
```
and verify changelog drainage in the `indexer` cron group.

## 7. Dimensions / sharded indexes (Commerce only)

Adobe Commerce supports `<fieldset>` dimension configurations for sharding an index by
store view or customer group. This is an advanced, Commerce-leaning surface that changes
the class hierarchy (`AbstractAction` instead of direct delegation). Do not scaffold
dimensions by default — note the capability exists and refer the developer to the
Commerce documentation when they need horizontal index sharding.

## 8. Changelog table growth

In schedule mode, if the indexer cron is disabled or stalled, the changelog table
(`mview_{indexer_id}_cl`) grows unbounded. Monitor its row count:
```sql
SELECT COUNT(*) FROM mview_{indexer_id}_cl;
```
A healthy system drains this table to near-zero after every cron run. Persistent growth
indicates a broken indexer cron or a mode set to `schedule` without the cron running.
