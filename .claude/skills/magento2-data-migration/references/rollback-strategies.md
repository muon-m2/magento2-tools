# Rollback Strategies

When and how to make a data migration reversible.

## Reversible vs Irreversible

| Operation | Reversible |
|-----------|-----------|
| INSERT new rows | Yes — DELETE WHERE seed = 1 |
| UPDATE existing rows | Yes IF original values were captured first |
| DELETE rows | Only if the deleted data was backed up |
| Schema change (column add) | Yes — column drop |
| Schema change (column rename) | Yes |
| Schema change (column drop) | No — data is lost |
| EAV attribute add | Yes — `removeAttribute` |
| EAV attribute delete | No — data lost |

## Backup-First Pattern

For UPDATEs and DELETEs, write the original to a backup table BEFORE mutating:

```php
$connection->query("
    INSERT INTO {migration_backup_table}
    SELECT * FROM {target_table} WHERE {condition}
");

$connection->query("
    UPDATE {target_table} SET col = ? WHERE {condition}
", [$newValue]);
```

Rollback: `INSERT ... ON DUPLICATE KEY UPDATE` from the backup table.

## Soft Delete

Instead of DELETE, set `is_deleted = 1`. Rollback is just `is_deleted = 0`.

## Migration Log Rollback Query

If using a `migration_log` table:

```php
public function rollback(): void
{
    $logRow = $connection->fetchRow(
        "SELECT rows_affected FROM {module}_migration_log WHERE migration_class = ?",
        [static::class]
    );

    // Reverse the operation using the captured info
    // ...

    $connection->delete('{module}_migration_log', ['migration_class = ?' => static::class]);
}
```

DataPatchInterface does NOT define a rollback method — Magento doesn't roll back patches.
Rollback is a separate operation invoked via a custom CLI command or by writing a
counter-patch.

## Counter-Patch Pattern

When a previously-applied patch needs reversing, write a new patch that undoes it:

```php
final class RevertMisguidedSeed implements DataPatchInterface
{
    public function apply(): self
    {
        $connection = $this->moduleDataSetup->getConnection();
        $connection->delete('{table}', ['source = ?' => 'misguided_seed_2024_05']);
        return $this;
    }

    public static function getDependencies(): array
    {
        return [\Vendor\Module\Setup\Patch\Data\MisguidedSeed::class];
    }

    public function getAliases(): array { return []; }
}
```

This is the safest approach for production migrations: the original patch is preserved
(so `setup:upgrade` history is intact), and a new patch undoes its effect.

## When to Refuse to Generate

If the user requests a destructive migration (DELETE without backup):

1. Warn explicitly: "This deletes data; rollback is impossible without a backup."
2. Offer the backup-first pattern.
3. Require `--allow-destructive` flag to proceed.
4. Include the warning in the generated patch's PHPDoc.

## Re-Run Safety Document

Every migration's report includes both:

```markdown
## Re-Run Safety

This patch is idempotent. Re-running `setup:upgrade` is safe — rows already present
are skipped.

## Rollback

To reverse this migration:
1. Identify rows seeded by this patch: `SELECT * FROM {table} WHERE source = 'patch_id'`.
2. Delete or revert: `DELETE FROM {table} WHERE source = 'patch_id'`.

Note: This patch is reversible because it uses the `source` column to identify seeded
rows. Patches without a source column may not be reversible.
```
