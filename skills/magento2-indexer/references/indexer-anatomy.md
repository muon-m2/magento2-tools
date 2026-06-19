# Indexer Anatomy

Reference for Magento 2 custom indexer structure, the two ActionInterfaces, the
delegation pattern, and the CLI commands used to manage indexers.

## indexer.xml structure

Location: `{Vendor}/{Module}/etc/indexer.xml` — merged with other modules' declarations.

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:Indexer/etc/indexer.xsd">
    <indexer id="{indexer_id}"
             view_id="{indexer_id}"
             class="{Vendor}\{Module}\Model\Indexer\{IndexerName}">
        <title translate="true">{Title}</title>
        <description translate="true">{Description}</description>
    </indexer>
</config>
```

Key attributes:
- `id` — unique string across the Magento instance; convention `{vendor}_{module}_{entity}`.
- `view_id` — **must match** the `<view id>` declared in `mview.xml`. Mismatch means
  scheduled partial reindex never fires.
- `class` — FQCN of the indexer class; must implement both ActionInterfaces (see below).

## The two ActionInterfaces

Magento's indexer system exposes two separate interfaces that share method names but live
in different namespaces:

### 1. `Magento\Framework\Indexer\ActionInterface`

Controls full and list-based reindex (called in "Update on Save" realtime mode):

| Method | Signature | Called when |
|--------|-----------|-------------|
| `executeFull()` | `void` | `indexer:reindex {id}` or admin "Reindex" button |
| `executeList(array $ids)` | `void` | realtime save of multiple entities |
| `executeRow($id)` | `void` | realtime save of a single entity |

### 2. `Magento\Framework\Mview\ActionInterface`

Controls scheduled partial reindex via the mview changelog:

| Method | Signature | Called when |
|--------|-----------|-------------|
| `execute(array $ids)` | `void` | cron drains the mview changelog batch |

### Handling the name clash

Both interfaces are named `ActionInterface`. Import them with distinct aliases:

```php
use Magento\Framework\Indexer\ActionInterface;
use Magento\Framework\Mview\ActionInterface as MviewActionInterface;

class {IndexerName} implements ActionInterface, MviewActionInterface
{
    ...
}
```

## Indexer → Action delegation pattern

The indexer class **must not** contain any reindex logic. Its only job is to dispatch to
an injected action class:

```php
public function __construct(
    private readonly {IndexerName}Action $action
) {
}

public function executeFull(): void
{
    $this->action->executeFull();
}

public function executeList(array $ids): void
{
    $this->action->execute($ids);
}

public function executeRow($id): void
{
    $this->action->execute([$id]);
}

public function execute(array $ids): void
{
    $this->action->execute($ids);
}
```

The action class (`{IndexerName}Action`) owns batching, SQL, and idempotency.
Tests mock the action — never the indexer internals.

## CLI commands

```bash
# Run a full reindex for one indexer
bin/magento indexer:reindex {indexer_id}

# Reindex all invalid indexers
bin/magento indexer:reindex

# Show indexer status and mode
bin/magento indexer:status

# Switch an indexer between realtime and schedule mode
bin/magento indexer:set-mode realtime {indexer_id}
bin/magento indexer:set-mode schedule {indexer_id}
```
