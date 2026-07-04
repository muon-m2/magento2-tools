---
name: magento2-deploy
description:
  Deploy one or more Magento 2 modules with pre-flight validation, ordered execution,
  smoke testing, and rollback on failure. Use when the user wants to deploy changes,
  enable a new module, run setup:upgrade after a code change, or roll back a previous
  deploy. Supports environment targets (local, staging, production) and produces a
  deploy report. Used by magento2-feature-implement, magento2-bug-fix, and
  magento2-module-upgrade for their D* deploy step.
---

# Magento 2 Deploy

Coordinate the Magento deploy sequence safely. Validate before, execute in order, smoke
test after, and roll back on any failure.

## Core Rules

- **Never deploy without validation.** Pre-flight checks must pass before any
  state-modifying command runs. See `references/pre-flight-checks.md`.
- **Atomic by failure class.** A failure in `setup:upgrade` halts the sequence; the skill
  does not attempt later steps in the chain.
- **Rollback by recipe.** Each step that can fail has an explicit rollback recipe — see
  `references/rollback-recipes.md`.
- **One environment at a time.** Multi-env deploys are sequential
  (local → staging → production), gated on explicit user approval between environments.
  See `references/multi-env-protocol.md`.
- **Production gating.** Deploys to production require: an explicit `--env=production`
  flag AND an interactive confirmation. `--auto --env=production` is rejected unless
  `--i-know-what-im-doing` is also passed.
- **Snapshot before high-risk steps.** Offer a snapshot (`--snapshot`) before any
  production deploy. The snapshot captures `generated/`, `var/`, optionally `vendor/`.
- **Reports are written before state changes commit.** If the skill crashes mid-deploy,
  the report folder shows where it stopped.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `runner`, `magento_cli`, `composer`. If `magento_cli`
is null, the deploy cannot proceed — abort with "no Magento CLI available; deploy
requires `bin/magento`."

### Phase 1 — Pre-flight Validation

Run **without modifying state**. See `references/pre-flight-checks.md` for the full
catalogue. Required by default:

| Check                      | Command                                                         | When required               |
|----------------------------|-----------------------------------------------------------------|-----------------------------|
| Module files exist         | `find {module-path} -name registration.php`                     | All deploys                 |
| Composer validate          | `composer validate --no-check-publish` per module composer.json | All deploys                 |
| PHPCS Magento2             | `{runner} vendor/bin/phpcs --standard=Magento2 {modules}`       | If `--strict`               |
| PHPStan level 8            | `{runner} vendor/bin/phpstan analyse --level=8 {modules}`       | If `--strict`               |
| Unit tests                 | `{runner} vendor/bin/phpunit {modules}/Test/Unit`               | All deploys                 |
| Disk space                 | `df -h $(pwd)`                                                  | All deploys (warn at < 1GB) |
| Git working tree clean     | `git status --porcelain`                                        | Production only             |
| No pending DB declarations | `{magento_cli} setup:db:status`                                 | All deploys                 |
| Composer install dry-run   | `composer install --no-dev --dry-run`                           | Production only             |

Any required check failing aborts the deploy with a clear report. Run via
`${CLAUDE_SKILL_DIR}/scripts/preflight.sh`.

### Phase 2 — Plan

Build the **deploy plan** as an ordered list of commands. Use the template matching the
target environment from `references/deploy-plan-templates.md`.

Default plan (local/staging):

```
1. {magento_cli} module:status {modules}                       # Verify state
2. {magento_cli} module:enable {modules}
3. {magento_cli} setup:upgrade
4. For each persistence module: setup:db-declaration:generate-whitelist --module-name=X
5. {magento_cli} cache:flush
6. {magento_cli} indexer:status                                # Report invalid indexers
```

Production plan additionally includes (in order):

```
1. maintenance:enable
... (steps from default)
5b. {magento_cli} setup:di:compile
5c. {magento_cli} setup:static-content:deploy -f
6.  {magento_cli} cache:flush
7.  {magento_cli} indexer:reindex                              # invalid indexers only
8.  {magento_cli} queue:consumers:start                        # new consumers only
9.  maintenance:disable
```

Present the plan. Wait for explicit "proceed" unless `--auto` is set (and `--env` is
not `production`).

### Phase 3 — Execute

Run each command in order via `${CLAUDE_SKILL_DIR}/scripts/execute-plan.sh` or by direct shell:

- Capture exit code, stdout, stderr per command.
- Exit code != 0: STOP. Invoke rollback (Phase 4).
- Exit code 0 with warnings on stderr: log them, continue.
- Update the in-progress report file after every step so a crash leaves an auditable
  partial state.

### Phase 4 — Rollback Recipes (per failed step)

Triggered only on failure during Phase 3. See `references/rollback-recipes.md` for the
authoritative table.

| Failed step                   | Rollback recipe                                                                            |
|-------------------------------|--------------------------------------------------------------------------------------------|
| `module:enable`               | `module:disable {modules}`                                                                 |
| `setup:upgrade`               | Restore the DB dump (see below), `git revert <deploy commit>`, then re-run `setup:upgrade` |
| `setup:di:compile`            | Restore `generated/` from snapshot (if `--snapshot` was set)                               |
| `setup:static-content:deploy` | Re-run from previous version's git ref                                                     |
| `cache:flush`                 | Idempotent — no rollback needed                                                            |
| `indexer:reindex`             | Mark indexers invalid; re-run after the underlying issue is fixed                          |
| `queue:consumers:start`       | `queue:consumers:stop {consumer}`; clear bad messages                                      |

**`setup:upgrade` rollback is lossy without a DB backup.** Reverting code and re-running
`setup:upgrade` does NOT undo schema or data changes already applied:

- Applied **data patches** are recorded in `patch_list` and will be neither re-applied nor
  reverted by `setup:upgrade` (unless they implement `PatchRevertableInterface` and the
  module is uninstalled).
- **Declarative-schema** column/table drops are destructive — the data is gone and cannot
  be recovered from code.

To roll the database back you need a dump taken *before* the deploy: run the snapshot with
`--include-db` (writes `db-{ts}.sql.gz`) and restore it before re-running `setup:upgrade`:

```
gunzip < db-{ts}.sql.gz | MYSQL_PWD=<pass> mysql -h <host> -P <port> -u <user> <dbname>
```

Rollback is best-effort. Report exactly what was rolled back and what wasn't, with file
paths and commands for manual completion.

### Phase 5 — Smoke Tests

Run smoke tests appropriate to the modules deployed. See `references/smoke-tests.md`.

| Surface                          | Smoke                                                                                     |
|----------------------------------|-------------------------------------------------------------------------------------------|
| Any                              | `{magento_cli} module:status` shows all expected modules enabled                          |
| Any                              | `{magento_cli} setup:db:status` shows "Magento Database is up to date"                    |
| `service_contracts` + `rest_api` | `curl -s {host}/rest/V1/{vendor}/{route}/` returns 200/401 (not 500)                      |
| `graphql`                        | `curl -s -X POST {host}/graphql -d '{"query":"{__schema{queryType{name}}}"}'` returns 200 |
| `admin_ui`                       | `curl -s {host}/admin/` returns 302 (login redirect)                                      |
| `frontend_ui`                    | `curl -s {host}/{vendor_lower}_{module_lower}/{route}/` returns expected status           |
| `cron`                           | crontab installed (`crontab -l \| grep cron:run`) + `cron_schedule` has recent rows (no `cron:status` command exists) |
| `queue`                          | `{magento_cli} queue:consumers:list` shows new consumers registered                       |

A smoke failure does NOT trigger rollback (the deploy completed) but is reported as a
"needs investigation" finding. Run via `${CLAUDE_SKILL_DIR}/scripts/smoke.sh`.

### Phase 6 — Report

Write to `{output_root}/deployments/{YYYY-MM-DD-HHMMSS}-{env}.md` AND the JSON sibling,
where `{output_root}` is the `--docs-root` value when the caller passed one, else
`{ctx.docs_root}` (see "Output Root" below). Use `templates/report.md`. Sections:

- Modules deployed (table with version, status)
- Environment
- Pre-flight results
- Plan executed (with timing per step)
- Per-step results (exit code, stdout digest, stderr digest)
- Smoke test results
- Failures + rollbacks (if any)
- Total time + bytes shifted
- Skill versions

## Reference Files

- `references/pre-flight-checks.md` — full pre-flight check catalogue.
- `references/deploy-plan-templates.md` — per-environment plan templates.
- `references/rollback-recipes.md` — per-step rollback procedures.
- `references/smoke-tests.md` — surface-driven smoke test catalogue.
- `references/multi-env-protocol.md` — local → staging → production gating.
- `references/maintenance-mode.md` — when to enable/disable maintenance mode.

## Templates

- `templates/report.md` — deploy report template (Markdown).
- `templates/plan.md` — pre-execution plan template (printed for user approval).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/preflight.sh` — run pre-flight checks; emit JSON pass/fail summary.
- `${CLAUDE_SKILL_DIR}/scripts/execute-plan.sh` — execute a plan file step-by-step, log per-step results.
- `${CLAUDE_SKILL_DIR}/scripts/smoke.sh` — run smoke tests for given module list.
- `${CLAUDE_SKILL_DIR}/scripts/snapshot.sh` — create a pre-deploy snapshot of `generated/`, `var/`, optionally
  `vendor/` (`--include-vendor`) and the database (`--include-db`, required for a non-lossy `setup:upgrade` rollback).

## Inputs

```
/magento2-deploy [--env=local|staging|production] [--strict] [--auto] [--snapshot] [--full] [--validate-only] [--docs-root=<path>] <Vendor>_<Module>...
```

| Flag                     | Default                               | Meaning                                                                                                                                                                      |
|--------------------------|---------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `--env`                  | `local`                               | Target environment. `production` requires interactive confirm.                                                                                                               |
| `--strict`               | off                                   | Require PHPCS + PHPStan to pass in pre-flight.                                                                                                                               |
| `--auto`                 | off                                   | Skip approval gate before Phase 3. Rejected on production unless `--i-know-what-im-doing`.                                                                                   |
| `--snapshot`             | off (local/staging) / prompted (prod) | Snapshot before deploy for rollback.                                                                                                                                         |
| `--full`                 | off (local/staging) / on (prod)       | Run optional steps (maintenance, static-deploy, di:compile).                                                                                                                 |
| `--validate-only`        | off                                   | Run **only** Phase 0 (context) + Phase 1 (pre-flight) + Phase 2 (plan). Skip Phase 3 onwards. Exit 0 if all required checks pass, 1 otherwise. Safe for release / CI gating. |
| `--i-know-what-im-doing` | off                                   | Required for `--auto --env=production` combination.                                                                                                                          |
| `--docs-root=<path>`     | unset                                  | Output-root override; see "Output Root" below.                                                                                                                              |

**Implementation note for `--validate-only`:** when this flag is set, the skill MUST exit after writing the validation
report. No `setup:upgrade`, no cache flush, no static-content:deploy, no maintenance toggling. The validation report
follows the same `{output_root}/deployments/{timestamp}-{env}.{md,json}` layout but with `"mode": "validate-only"` in the JSON
and a `Validation only — no deploy executed` banner in the markdown.

## Outputs

```
{output_root}/deployments/{timestamp}-{env}.md                # Markdown report
{output_root}/deployments/{timestamp}-{env}.json              # Machine-readable for CI
{output_root}/deployments/{timestamp}-{env}.snapshot.tar.gz   # Optional snapshot for rollback
```

`{output_root}` (`.docs` by default, `{ctx.docs_root}`) is anchored at the project root,
never under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location**
rule in `magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill has an inline emitter (no `build-findings.sh`): the pre-flight, execute-plan,
smoke, and snapshot scripts already take their output path from caller-supplied
`OUTPUT_FILE`/`OUTPUT_DIR` env vars or arguments, so no script changes were needed. The
skill itself accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`) and, when set, writes the Markdown +
JSON report and invokes `snapshot.sh <path>/deployments` (the script's output dir is a
positional argument, not an env var) so all deploy artifacts land under
`<path>/deployments/`; otherwise they default to `{ctx.docs_root}/deployments/`.
Orchestrators such as `magento2-feature-implement` pass this to collect a run's
artifacts under one folder.

## Acceptance Criteria

- Aborts on any required pre-flight failure with a clear list of failed checks.
- Never proceeds to production without explicit interactive confirmation.
- Rollback restores the prior known-good state for any failure during `module:enable`,
  `setup:upgrade`, or `setup:di:compile`.
- Smoke tests run for every applicable surface.
- Report contains enough information to re-deploy or roll back without consulting the
  skill again.

## Notes on Safety

- **Default-deny on destructive steps.** Production deploys require both a flag and an
  interactive confirm.
- **No flag combination silently does dangerous things.** `--auto --env=production`
  rejected unless `--i-know-what-im-doing` is also set.
- **Reports are written before state changes commit.** If the skill crashes mid-deploy,
  the report folder shows where it stopped.
- **Snapshots are opt-in but offered every time on production.** The first prompt in
  production deploys asks "snapshot before deploy? (y/n)".

## Related Skills

| Caller                       | Use                                                        |
|------------------------------|------------------------------------------------------------|
| `magento2-feature-implement` | Phase 5 D1 task                                            |
| `magento2-bug-fix`           | Phase 6 (optional)                                         |
| `magento2-module-upgrade`    | After upgrade is patched                                   |
| `magento2-release`           | Phase 2 (validate only — `--strict` pre-flight)            |
| Direct user                  | `/magento2-deploy --env=staging Acme_ModuleA Acme_ModuleB` |
