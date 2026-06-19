# Cron Job Anatomy

Magento's cron system discovers jobs from each module's `etc/crontab.xml`. The
`bin/magento cron:run` command (or the OS crontab calling `cron.php`) dispatches jobs
per group.

## crontab.xml structure

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Cron:etc/crontab.xsd">
    <group id="default">
        <job name="acme_orders_sync"
             instance="Acme\Orders\Cron\SyncOrders"
             method="execute">
            <!-- Option A: fixed cron expression -->
            <schedule>*/15 * * * *</schedule>
        </job>
    </group>
</config>
```

**`<schedule>` vs `<config_path>`**

| Element | When to use |
|---------|-------------|
| `<schedule>` | Fixed interval; not configurable at runtime. |
| `<config_path>` | Reads a cron expression from admin Stores → Configuration. Pair with `magento2-system-config` to add the field. |

```xml
<!-- config_path variant -->
<job name="acme_orders_sync" instance="Acme\Orders\Cron\SyncOrders" method="execute">
    <config_path>acme_orders/cron/sync_schedule</config_path>
</job>
```

## Cron groups

Groups control concurrency, timeouts, and overlap behaviour:

| Group | Typical use |
|-------|-------------|
| `default` | Standard Magento jobs; runs every minute via `cron.php`. |
| `index` | Indexer jobs; separate process, avoids blocking default jobs. |
| Custom | Define in `etc/cron_groups.xml` when you need isolation or specific timeouts. |

To run a single group manually:

```bash
bin/magento cron:run --group=default
```

## Job class

The `instance` FQCN must have a public `execute()` method (the `method` attribute in
`crontab.xml` is the method name, not necessarily `execute`):

```php
namespace Acme\Orders\Cron;

class SyncOrders
{
    public function __construct(
        private readonly OrderSyncer $syncer
    ) {
    }

    public function execute(): void
    {
        $this->syncer->syncPendingOrders();
    }
}
```

## Locking for long-running jobs

When a job might overlap (slow queries, external API calls), acquire a lock before work:

```php
// Pseudo-code — use Magento\Framework\Lock\LockManagerInterface
if (!$this->lockManager->lock('acme_orders_sync', 0)) {
    return; // Another process is running; skip silently.
}
try {
    $this->syncer->syncPendingOrders();
} finally {
    $this->lockManager->unlock('acme_orders_sync');
}
```

See `${CLAUDE_SKILL_DIR}/references/pitfalls.md` for the full overlap/idempotency
checklist.
