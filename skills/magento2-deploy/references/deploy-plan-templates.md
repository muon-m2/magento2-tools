# Deploy Plan Templates

One template per environment. Each step is an exact shell command with placeholders.

## Local (`--env=local`)

Default — fastest, no maintenance mode, no static-content deploy. Use during dev.

```
1. {magento_cli} module:enable {modules}
2. {magento_cli} setup:upgrade
3. For each persistence module:
   {magento_cli} setup:db-declaration:generate-whitelist --module-name={module}
4. {magento_cli} cache:flush
5. {magento_cli} indexer:status                  # report only
```

Optional steps (skip unless `--full`):
- `setup:di:compile`
- `setup:static-content:deploy -f`

## Staging (`--env=staging`)

Adds DI compile and static-content deploy. No maintenance mode. Safe for shared dev
environments.

```
1.  {magento_cli} module:enable {modules}
2.  {magento_cli} setup:upgrade
3.  For each persistence module:
    {magento_cli} setup:db-declaration:generate-whitelist --module-name={module}
4.  {magento_cli} setup:di:compile
5.  {magento_cli} setup:static-content:deploy -f --theme={frontend_theme} --theme={admin_theme}
6.  {magento_cli} cache:flush
7.  {magento_cli} indexer:reindex                # invalid indexers only
```

## Production (`--env=production` + interactive confirm)

Full sequence with maintenance mode. Slowest. Most aggressive validation.

```
0.  Capture snapshot (if --snapshot or user said y to prompt)
1.  {magento_cli} maintenance:enable
2.  {magento_cli} module:enable {modules}
3.  {magento_cli} setup:upgrade
4.  For each persistence module:
    {magento_cli} setup:db-declaration:generate-whitelist --module-name={module}
5.  {magento_cli} setup:di:compile
6.  {magento_cli} setup:static-content:deploy -f --theme={frontend_theme} --theme={admin_theme}
7.  {magento_cli} cache:flush
8.  {magento_cli} indexer:reindex                # invalid indexers only
9.  {magento_cli} queue:consumers:list           # report newly-added
10. {magento_cli} maintenance:disable
```

## Rollback Plan (triggered by Phase 4)

```
1. {magento_cli} maintenance:enable              # if not already on
2. Run the per-step rollback recipe from rollback-recipes.md
3. {magento_cli} cache:flush
4. {magento_cli} maintenance:disable
```

## Module Order Within a Single Deploy

When deploying multiple modules at once, enable them in dependency order. Use the
output of `module:status --enabled` plus the `<sequence>` declarations to topo-sort.

A module with `<sequence>{X}</sequence>` must be enabled AFTER {X}. If X is not in the
deploy list, ensure X is already enabled or include it.

## Persistence Module Detection

A module is "persistence" if any of these exist:
- `etc/db_schema.xml`
- `Setup/Patch/Schema/*.php`
- `Setup/Patch/Data/*.php` (data patches count for `generate-whitelist`)
- Legacy `Setup/InstallSchema.php` or `Setup/UpgradeSchema.php`

`generate-whitelist` runs only for persistence modules.

## Theme Detection for Static Content

Read `{ctx.theme.frontend}` and `{ctx.theme.adminhtml}` from the context resolver. Use
their package names verbatim in the `--theme` flag.

Examples:
- `Magento/luma` (Luma frontend)
- `Magento/blank` (Blank frontend)
- `Hyva/default` (Hyva frontend)
- `Magento/backend` (Admin)

For custom themes: `{Vendor}/default` is typical.
