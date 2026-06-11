# Rector Rule Sets

Rector rule sets to apply per upgrade target.

## PHP Upgrade Sets

| Target PHP | Rule set |
|------------|----------|
| 8.0 | `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_80` |
| 8.1 | `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_81` |
| 8.2 | `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_82` |
| 8.3 | `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_83` |
| 8.4 | `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_84` |

## Magento Upgrade Sets

There is **no official Adobe-published Rector rule set** on Packagist. Drive Magento
upgrades with the core `rector/rector` package and a hand-listed set of rules derived
from `references/deprecation-map.md`:

```php
use Rector\Config\RectorConfig;

return RectorConfig::configure()
    ->withPaths([__DIR__ . '/app/code/{Vendor}/{Module}'])
    ->withRules([
        // List specific rules from references/deprecation-map.md, e.g.:
        \Rector\Php80\Rector\Class_\ClassPropertyAssignToConstructorPromotionRector::class,
    ]);
```

> Community Magento rule sets exist (search Packagist for `rector` + `magento`), but none
> are first-party. If you adopt one, **verify each rule against the target Magento version
> before use** — community sets lag behind releases and may rewrite working code.

## Quality / Cleanup Sets

Run after the upgrade-target sets to clean up. These live in
`Rector\Set\ValueObject\SetList`:

| Set                         | Effect                        |
|-----------------------------|-------------------------------|
| `SetList::CODE_QUALITY`     | Code-quality improvements     |
| `SetList::TYPE_DECLARATION` | Add missing type declarations |
| `SetList::DEAD_CODE`        | Remove dead code              |

```php
use Rector\Set\ValueObject\SetList;

return RectorConfig::configure()
    ->withSets([SetList::CODE_QUALITY, SetList::TYPE_DECLARATION, SetList::DEAD_CODE]);
```

Apply quality sets only after the user reviews — they make many small changes.

## Dry Run First

```
{ctx.runner} vendor/bin/rector process --dry-run {ctx.magento_root}/app/code/{Vendor}/{Module}
```

Review the diff. Apply when ready:

```
{ctx.runner} vendor/bin/rector process {ctx.magento_root}/app/code/{Vendor}/{Module}
```

## Per-Rule Application

The `--only` CLI flag was removed from Rector years ago. To apply one rule at a time
(preferred for large changes), write a temporary `rector.php` that lists just that rule,
then run `process` against it:

```php
// rector.php (temporary — narrow to a single rule)
use Rector\Config\RectorConfig;
use Rector\TypeDeclaration\Rector\ClassMethod\AddVoidReturnTypeWhereNoReturnRector;

return RectorConfig::configure()
    ->withPaths([__DIR__ . '/app/code/{Vendor}/{Module}'])
    ->withRules([AddVoidReturnTypeWhereNoReturnRector::class]);
```

```
{ctx.runner} vendor/bin/rector process --config rector.php
```

Swap the single rule in `->withRules([...])` for the next one and re-run. A commit per
single-rule run makes reverting one easier.

## When Rector Isn't Available

Document the unavailable scanner. Mark all findings as `manual-fixable` even when Rector
would have auto-fixed them. The user can install Rector and re-run, or accept manual
fixes for this run.

## Core Rector Rules Worth Knowing

These ship with `rector/rector` and help with PHP-level modernization (not Magento
patterns specifically):

| Rule                                                                             | Effect                                             |
|----------------------------------------------------------------------------------|----------------------------------------------------|
| `Rector\Php83\Rector\ClassConst\AddTypeToConstRector`                            | Adds types to class constants (PHP 8.3+)           |
| `Rector\Php80\Rector\Class_\ClassPropertyAssignToConstructorPromotionRector`     | Constructor property promotion (PHP 8.0+)          |
| `Rector\TypeDeclaration\Rector\ClassMethod\AddVoidReturnTypeWhereNoReturnRector` | Adds `void` return type where no value is returned |

> There is no core Rector rule that rewrites `ObjectManager` usage into constructor
> injection, nor one that converts `Setup/InstallData` → `Setup/Patch/Data` — those are
> Magento-specific transforms and must be done manually (see `references/deprecation-map.md`).

The exact rule list depends on the Rector version installed. Use
`vendor/bin/rector list-rules` to enumerate what is actually available.
