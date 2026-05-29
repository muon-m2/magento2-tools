# Rollback Recipes

Per-step rollback procedures. Triggered only when Phase 3 (execute) hits a non-zero
exit code from the corresponding step.

Rollback is best-effort. Each recipe ends by either restoring known-good state or
clearly reporting "manual intervention required" with the next steps.

## `module:enable` failed

Likely cause: missing dependency, missing `registration.php`, or DI conflict.

```
{magento_cli} module:disable {modules}
{magento_cli} cache:flush
```

If the module was partially registered (some files exist in `generated/`), also:

```
rm -rf generated/code/{Vendor}/{Module}
rm -rf generated/metadata/{Vendor}_{Module}*
```

## `setup:upgrade` failed

Likely cause: failing data/schema patch or schema declaration conflict.

1. Read the exact failure from stdout/stderr.
2. Identify the failing patch class (usually visible in the trace).
3. If `--snapshot` was set:
   ```
   git revert <deploy commit hash>
   ./scripts/restore-snapshot.sh {snapshot.tar.gz}
   {magento_cli} setup:upgrade
   ```
4. If no snapshot:
   ```
   git revert <deploy commit hash>
   {magento_cli} setup:upgrade
   ```
5. If the schema has already partially applied AND there is no down-migration: STOP.
   Report which patch ran successfully and which failed; the DBA must inspect manually.

## `setup:di:compile` failed

Likely cause: missing required type, syntax error, or interface mismatch in a generated
factory.

```
rm -rf generated/code generated/metadata
{magento_cli} setup:di:compile
```

If a second run also fails:
- If `--snapshot`: restore `generated/` from snapshot. The deploy is partial; flag
  for manual resolution.
- If no snapshot: report. Manual intervention required.

## `setup:static-content:deploy` failed

Likely cause: missing theme dependency, JS/LESS compile error.

```
rm -rf pub/static/* var/view_preprocessed/*
{magento_cli} setup:static-content:deploy -f --theme={previous_theme_state}
```

Re-deploy with the previous version's theme list. Static failures are rarely
deploy-blocking — the prior assets are still being served from CDN/cache.

## `cache:flush` failed

Idempotent. No rollback needed. Re-run.

## `indexer:reindex` failed

```
{magento_cli} indexer:reset {indexer_id}
```

Marks the indexer invalid; on-save or scheduled cron will re-process. The data is
still queryable from the source tables (just not from the flat tables).

## `queue:consumers:start` failed

```
{magento_cli} queue:consumers:stop {consumer}
```

If the queue contains poison messages: manual inspection of RabbitMQ / DB queue table.

## `maintenance:enable` / `maintenance:disable` failed

Most often: file permission issue on `var/.maintenance.flag`. Manual:

```
touch var/.maintenance.flag          # enable
rm -f var/.maintenance.flag          # disable
```

## Snapshot Restore

```
mv generated generated.failed.$(date +%s)
mv var var.failed.$(date +%s)
tar -xzf {snapshot}.tar.gz -C .
```

After restore: `cache:flush` and verify with smoke tests.

## Reporting Rollback

The deploy report lists each rollback action taken, the result (success / partial /
failed), and the recommended manual next step for any partial result. Critical: never
mark a deploy "succeeded" if any rollback ran — it's "deploy failed; rollback {result}".
