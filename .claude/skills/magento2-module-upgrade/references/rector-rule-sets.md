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

Adobe ships a Magento Rector rule set (`magento/rector-rules-magento`). Apply the set
matching the target Magento version.

```php
return RectorConfig::configure()
    ->withSets([
        \Magento\Rector\Sets\MagentoLevelSetList::UP_TO_MAGENTO_2_4_8,
    ]);
```

Without the official set, fall back to:

```php
return RectorConfig::configure()
    ->withRules([
        // List specific rules from references/deprecation-map.md
    ]);
```

## Quality / Cleanup Sets

Run after the upgrade-target sets to clean up:

| Set | Effect |
|-----|--------|
| `LevelSetList::UP_TO_QUALITY_*` | Code-quality improvements |
| `LevelSetList::UP_TO_TYPE_DECLARATION_*` | Add missing type declarations |
| `LevelSetList::UP_TO_DEAD_CODE_*` | Remove dead code |

Apply quality sets only after the user reviews — they make many small changes.

## Dry Run First

```
{ctx.runner} vendor/bin/rector process --dry-run src/app/code/{Vendor}/{Module}
```

Review the diff. Apply when ready:

```
{ctx.runner} vendor/bin/rector process src/app/code/{Vendor}/{Module}
```

## Per-Rule Application

To apply one rule at a time (preferred for large changes):

```
{ctx.runner} vendor/bin/rector process --only=AddVoidReturnTypeWhereNoReturnRector \
    src/app/code/{Vendor}/{Module}
```

Commit per-rule application makes reverting one easier.

## When Rector Isn't Available

Document the unavailable scanner. Mark all findings as `manual-fixable` even when Rector
would have auto-fixed them. The user can install Rector and re-run, or accept manual
fixes for this run.

## Magento-Specific Rules Worth Knowing

| Rule | Effect |
|------|--------|
| `ReplaceObjectManagerWithConstructorInjectionRector` | Replaces `ObjectManager` calls with injected dependencies |
| `AddTypedConstantRector` | Adds types to constants (PHP 8.3+) |
| `MoveAttributesBeforeMethodSignatureRector` | PHP 8 attribute conversion |
| `MagentoSetupUpgradeToPatchRector` (if present) | Convert `InstallData` → `Setup/Patch/Data` |

The exact rule list depends on the Rector version installed. Use
`vendor/bin/rector list-rules` to enumerate.
