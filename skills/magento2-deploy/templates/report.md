# Deploy Report — {timestamp} {env}

Environment: {env}
Started: {YYYY-MM-DD HH:MM:SS UTC}
Finished: {YYYY-MM-DD HH:MM:SS UTC}
Duration: {N} seconds
Status: {Success | Failure | Partial (rolled back)}
Skill versions:

- magento2-deploy@1.2.1
- magento2-context@1.6.1

## Modules Deployed

| Module               | Version (composer) | Status  |
|----------------------|--------------------|---------|
| `{Vendor}_{ModuleA}` | 1.4.0              | Enabled |
| `{Vendor}_{ModuleB}` | 2.0.1              | Enabled |

## Pre-Flight

| Check               | Required | Result  | Notes                           |
|---------------------|----------|---------|---------------------------------|
| module-registration | Yes      | Pass    | —                               |
| composer-validate   | Yes      | Pass    | —                               |
| unit-tests          | Yes      | Pass    | 42 tests, 0 failures, 1 skipped |
| disk-space          | Yes      | Pass    | 12GB free                       |
| phpcs               | No       | Skipped | --strict not set                |

## Plan

```
1. {magento_cli} module:enable {Vendor}_{ModuleA} {Vendor}_{ModuleB}
2. {magento_cli} setup:upgrade
3. {magento_cli} setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleA}
4. {magento_cli} cache:flush
5. {magento_cli} indexer:status
```

## Execution

| # | Command            | Exit | Duration | Notes                                  |
|---|--------------------|------|----------|----------------------------------------|
| 1 | module:enable      | 0    | 2s       | —                                      |
| 2 | setup:upgrade      | 0    | 18s      | Applied 2 schema patches, 1 data patch |
| 3 | generate-whitelist | 0    | 3s       | —                                      |
| 4 | cache:flush        | 0    | 1s       | —                                      |
| 5 | indexer:status     | 0    | 1s       | All indexers valid                     |

## Smoke Tests

| Surface       | Test                            | Result | Detail                       |
|---------------|---------------------------------|--------|------------------------------|
| Module status | enabled list                    | Pass   | All deployed modules enabled |
| DB status     | up-to-date                      | Pass   | —                            |
| REST API      | GET /V1/{vendor}/{route}/health | Pass   | 200                          |
| Cron          | jobs registered                 | Pass   | acme_export_run found        |

## Failures / Rollbacks

None.

## Snapshot

{Path to snapshot tar.gz, or "Not requested"}

## Next Steps

- Monitor `var/log/exception.log` for the next 24 hours.
- Run smoke validation on the public site URL.
- If issues arise, rollback via: `git revert {deploy commit}` + `/magento2-deploy --env={env} {modules}`
