# Deprecation Map

Common Magento 2 deprecations and their replacements. Used by the Phase 2 scanner.

## Object Manager

| Deprecated | Replacement |
|------------|-------------|
| `\Magento\Framework\App\ObjectManager::getInstance()` | Constructor injection |
| `$objectManager->create($class)` in production code | Factory injection |
| `$objectManager->get($class)` in production code | Direct constructor injection |

## Helper

| Deprecated | Replacement |
|------------|-------------|
| `Magento\Framework\App\Helper\AbstractHelper` (extending) | ViewModel + dedicated service |
| `$this->_storeManager` in helpers | Constructor-injected `StoreManagerInterface` |

## Setup Schema / Data

| Deprecated | Replacement |
|------------|-------------|
| `Setup/InstallSchema.php` | `etc/db_schema.xml` |
| `Setup/UpgradeSchema.php` | `etc/db_schema.xml` + patches |
| `Setup/InstallData.php` | `Setup/Patch/Data/*.php` |
| `Setup/UpgradeData.php` | `Setup/Patch/Data/*.php` |

## Repository / Collection

| Deprecated | Replacement |
|------------|-------------|
| `$collection->load(); foreach (...)` | `$collection->getItems()` after filters |
| `Magento\Eav\Model\Entity\Collection\AbstractCollection::addAttributeToSelect('*')` | Specific attribute list |
| Loading entity by ID in `Model` constructor | Lazy-load via Repository |

## Block / Template

| Deprecated | Replacement |
|------------|-------------|
| `$this->getRequest()` in templates | Inject service via ViewModel |
| `$block->getChildHtml()` for layout-specific blocks | Layout XML containers |
| `Mage::*` (legacy M1) | Magento\* equivalents |

## Cron

| Deprecated | Replacement |
|------------|-------------|
| `<job name=...><schedule>* * * * *</schedule></job>` directly in module | Use a config path: `<schedule_config_path>...</schedule_config_path>` |
| Cron classes extending `Magento\Cron\Model\Job` | Plain classes with `execute()` |

## DI

| Deprecated | Replacement |
|------------|-------------|
| `Magento\Framework\Module\Plugin\DbStatusValidator` (since 2.4.6) | n/a — internal plugin |
| Plugin without `sortOrder` on a method with multiple plugins | Always add explicit `sortOrder` |

## GraphQL

| Deprecated | Replacement |
|------------|-------------|
| `Magento\Framework\GraphQl\Query\Resolver::resolve()` returning `[]` for not-found | Throw `GraphQlNoSuchEntityException` |
| Hardcoded auth check in resolver body | `@auth` directive or `Magento\Framework\GraphQl\Config\Element\Field::getResolver()` annotation |

## Patterns to Grep For

```
# ObjectManager misuse
grep -rE 'ObjectManager::getInstance' {ctx.magento_root}/app/code/{Vendor}/{Module}

# Legacy install
find {ctx.magento_root}/app/code/{Vendor}/{Module}/Setup -name 'Install*.php' -o -name 'Upgrade*.php'

# Legacy M1 calls
grep -rE 'Mage::(getModel|getSingleton|helper|getConfig|app)' {ctx.magento_root}/app/code/{Vendor}/{Module}

# Untyped constructor params
grep -rE 'function __construct\([^)]*\$\w+[^,)]*\)' {ctx.magento_root}/app/code/{Vendor}/{Module} | grep -v ': '
```

## Adding to the Map

When you encounter a deprecation not listed here, add a row:

```markdown
| `{old API}` | `{replacement}` |
```

And add a detection pattern if the scanner can handle it. The map is curated, not
exhaustive — release notes are authoritative.
