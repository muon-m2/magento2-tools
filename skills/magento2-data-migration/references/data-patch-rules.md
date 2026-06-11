# DataPatchInterface Rules

## Required Methods

```php
final class MyPatch implements DataPatchInterface
{
    public function apply(): self { /* do the work */ return $this; }

    public static function getDependencies(): array { return []; }

    public function getAliases(): array { return []; }
}
```

All three methods are required. `getDependencies()` and `getAliases()` return arrays
even when empty.

## Setup Wrapping

```php
public function apply(): self
{
    $this->moduleDataSetup->getConnection()->startSetup();
    try {
        // mutations
    } finally {
        $this->moduleDataSetup->getConnection()->endSetup();
    }
    return $this;
}
```

`startSetup()` / `endSetup()` set up indexes' deferred-write mode for performance.

## Idempotency

Every patch must be safe to re-run. Common patterns:

### Check before insert

```php
$exists = $connection->fetchOne(
    "SELECT COUNT(*) FROM {$table} WHERE name = ?",
    [$row['name']]
);
if (!$exists) {
    $connection->insert($table, $row);
}
```

### INSERT IGNORE

```php
$connection->insertOnDuplicate($table, $rows, ['updated_at']);
```

Updates only the listed columns when a UNIQUE key conflicts.

### Hash-tracked

For complex multi-step seeds:

Inject a reader and a writer — these are two different services:
`Magento\Framework\App\Config\ScopeConfigInterface $scopeConfig` (read) and
`Magento\Framework\App\Config\Storage\WriterInterface $configWriter` (write,
`save()`/`delete()` only — it has no read method).

```php
$patchHash = hash('sha256', serialize($payload));
if ($this->scopeConfig->getValue("{module}/migrated/{patch_id}") === $patchHash) {
    return $this; // already applied
}
// ... do work
$this->configWriter->save("{module}/migrated/{patch_id}", $patchHash);
```

`ScopeConfigInterface` reads from a cached snapshot, so a value written via
`WriterInterface` is not visible to `getValue()` within the **same** request until the
config cache is reloaded. Across separate `setup:upgrade` runs (the normal case for data
patches) this is not an issue, because each run starts with a fresh config snapshot.

## Dependencies

```php
public static function getDependencies(): array
{
    return [
        \Vendor\Module\Setup\Patch\Data\CreateBaseStatuses::class,
        \Vendor\OtherModule\Setup\Patch\Data\InstallCustomerGroups::class,
    ];
}
```

Magento applies dependencies before the dependent patch. Circular dependencies error
out at `setup:upgrade`.

## Aliases

Used during patch class renames:

```php
public function getAliases(): array
{
    return ['Vendor\\Module\\Setup\\Patch\\Data\\OldNameOfThisPatch'];
}
```

Magento treats the alias as already-applied, preventing re-execution.

## Common Mistakes

| Mistake | Symptom |
|---------|---------|
| Forgetting `getDependencies()` | Patch fails to load (interface violation) |
| Non-idempotent: bare `INSERT` | Duplicate rows on every `setup:upgrade` |
| Skipping `startSetup()` | Schema-change patches lock too aggressively |
| Mutating data outside a transaction | Partial state on failure |
| Patch class in wrong namespace | Magento can't find it; silently skipped |

## File Location

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Setup/Patch/Data/{PatchClassName}.php
```

Patch class name MUST match the file name. Magento uses class name for tracking
"applied" state.
