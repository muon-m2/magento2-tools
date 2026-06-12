# Deploy Plan — {timestamp} {env}

Environment: {env}
Modules: {Vendor}_{ModuleA}, {Vendor}_{ModuleB}
Runner: `{ctx.runner}`
Magento CLI: `{ctx.magento_cli}`
Skill versions:

- magento2-deploy@1.2.0
- magento2-context@1.6.0

## Pre-Flight Result

All required checks passed. Optional checks (strict mode): {skipped|run}.

## Steps

```
1. {magento_cli} module:enable {Vendor}_{ModuleA} {Vendor}_{ModuleB}
2. {magento_cli} setup:upgrade
3. For each persistence module: setup:db-declaration:generate-whitelist
4. {magento_cli} cache:flush
5. {magento_cli} indexer:status
```

## Estimated Duration

~{N} seconds (based on prior local deploys; production typically takes longer)

## Rollback Plan

If any step fails:

- `module:enable` → `module:disable {modules}`
- `setup:upgrade` → `git revert {commit}` + re-run
- `setup:di:compile` → restore `generated/` from snapshot (if --snapshot)

See `references/rollback-recipes.md` for full per-step recipes.

## Production-Only Confirmation

(Only shown when --env=production)

Snapshot before deploy? `{yes/no/prompted}`
Maintenance window communicated? `{yes/no}`

Type exactly **`deploy production`** to proceed. Anything else cancels.

## Approval

For local/staging: reply **proceed** to execute, or describe any required changes.
For production: type the exact confirmation string above.
