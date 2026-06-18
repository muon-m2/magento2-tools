# Upgrade Report: {Vendor}_{Module} {from} → {to}

Date: {YYYY-MM-DD}
Status: {Complete | Partial | Failed}
Skill versions:
  - magento2-module-upgrade@1.1.0
  - magento2-module-review@2.3.1
  - magento2-test-generate@1.1.2
- magento2-context@1.6.1

## Scope

- Magento: `{from_magento}` → `{to_magento}`
- PHP: `{from_php}` → `{to_php}`
- Module(s): `{Vendor}_{Module}`

## Scanners Run

| Scanner                         | Available                        | Findings                     |
|---------------------------------|----------------------------------|------------------------------|
| Adobe UCT (`uct upgrade:check`) | no (Open Source — edition-gated) | —                            |
| Rector                          | yes                              | 18 (12 auto-fixed, 6 manual) |
| PHPStan                         | yes                              | 4 errors at level 8          |
| phpcs --standard=Magento2       | no                               | —                            |
| PHPCompatibility                | yes                              | 2 PHP 8.2 issues             |

## Findings

### Auto-fixed via Rector

- Implicit nullable params (3 files) — `LevelSetList::UP_TO_PHP_82`
- `${name}` → `{$name}` interpolation (7 files)
- Type-declaration additions (8 files)

### Manually fixed

- `Service/PriceCalculator.php:47` — removed `ObjectManager::getInstance()` call.
- `Model/Item.php:88` — replaced deprecated `_helperFactory` field with constructor
  injection.

### BC breaks

- **Removed `OrderRepository::loadByIncrementId()`** — see `UPGRADE.md`.

### Test results

- Unit: 42 tests, 0 failures, 1 skipped
- Integration: 8 tests, 0 failures
- API: 4 tests, 0 failures

### Review (diff mode)

- Critical: 0
- High: 0 (1 was introduced and fixed in Phase 6)
- Medium: 2 (logged; non-blocking)
- Low: 5

## composer.json bump

`{Vendor}_{Module}` version: `1.4.0` → `2.0.0` (major bump due to BC break).

## Recommended Next Steps

- Update CHANGELOG.md
- Run `/magento2-deploy --env=staging {Vendor}_{Module}`
- Notify consumers of the BC break (see UPGRADE.md)
