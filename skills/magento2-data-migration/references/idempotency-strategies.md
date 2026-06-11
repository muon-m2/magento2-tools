# Idempotency Strategies

## 1. Lookup-Then-Insert (Most Common)

```php
$exists = $connection->fetchOne(
    "SELECT entity_id FROM {table} WHERE unique_key = ?",
    [$row['unique_key']]
);
if (!$exists) {
    $connection->insert($table, $row);
}
```

Pros: Clear intent, easy to debug.
Cons: Two queries per row (lookup + insert).

## 2. Unique Constraint + `INSERT IGNORE` / `ON DUPLICATE KEY`

```php
$connection->insertOnDuplicate($table, $rows, ['updated_at']);
```

When a UNIQUE key collides, MySQL updates only the listed columns (or skips entirely with
INSERT IGNORE).

Pros: One query; atomic.
Cons: Requires a UNIQUE index on the lookup key; silently swallows other errors.

## 3. Hash-Tracked Config

Read with `Magento\Framework\App\Config\ScopeConfigInterface` and write with
`Magento\Framework\App\Config\Storage\WriterInterface` — the writer (`$configWriter`) only
exposes `save()`/`delete()`, so the read must go through `$scopeConfig`:

```php
$signature = hash('sha256', serialize($payload));
$flag = $this->scopeConfig->getValue("{module}/migrations/{patch_id}");
if ($flag === $signature) {
    return $this; // already applied
}
// ... do work
$this->configWriter->save("{module}/migrations/{patch_id}", $signature);
```

Pros: Works for multi-row operations as a unit; detects "different input" cases.
Cons: Requires config storage; not row-level. `ScopeConfigInterface` reads a cached
snapshot, so a freshly written flag is only visible on the next run (fine for data patches,
which run once per `setup:upgrade`).

## 4. Migration Log Table

Create a `{module}_migration_log` table tracking applied migrations:

```sql
CREATE TABLE {module}_migration_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration_class VARCHAR(255) NOT NULL UNIQUE,
    applied_at DATETIME NOT NULL,
    source_signature VARCHAR(64),
    rows_affected INT
);
```

Pros: Detailed audit trail; supports rollback queries.
Cons: Extra table; more code.

## 5. Composite Key

For idempotency across multiple columns:

```sql
SELECT entity_id FROM {table} WHERE col_a = ? AND col_b = ? AND store_id = ?
```

When no single column is unique, combine.

## Picking a Strategy

| Use case | Strategy |
|----------|----------|
| Seeding 5 reference rows | Lookup-then-insert |
| Importing 100K rows with email/SKU uniqueness | UNIQUE + ON DUPLICATE KEY |
| Migrating settings (single payload) | Hash-tracked config |
| Multi-step migration with rollback need | Migration log table |
| Per-store-view EAV value | Composite key (entity_id + attribute_id + store_id) |

## Anti-Patterns

- **No idempotency at all** — `setup:upgrade` is run multiple times; the patch must be safe.
- **Idempotency check after insert** — race condition between concurrent setups.
- **`DELETE FROM {table}` before insert** — destructive; not idempotent; loses data.

## Re-Run Safety Statement

Every patch's report must include:

> Re-run safety: This patch is idempotent. Re-running `setup:upgrade` will skip rows
> already present (based on {unique_key}). No data is mutated or deleted on re-run.

When NOT idempotent (rare), state it explicitly so the user knows:

> Re-run safety: This patch is NOT idempotent. Running it twice will duplicate rows.
> Apply once per environment; track in `migration_log`.
