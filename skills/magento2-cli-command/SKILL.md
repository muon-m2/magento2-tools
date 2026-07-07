---
name: magento2-cli-command
description:
    Scaffold a `bin/magento` console command (Symfony Command + commandList registration +
    arguments/options/exit-codes) or a cron job (crontab.xml + job class, fixed or
    config-path schedule) on an existing module. Use for 'add a CLI command' / 'add a
    scheduled job'. Business logic belongs in a service the command/job calls. For a new
    module use `magento2-module-create` first.
---

# Magento 2 CLI Command / Cron Job

Scaffold a `bin/magento` console command or a cron job onto an **existing** Magento 2
module. Two modes:

- **command** — Symfony `Command` subclass, `CommandList` DI registration,
  arguments, options, and `Cli::RETURN_*` exit codes.
- **cron** — `crontab.xml` job declaration plus a job class with a delegate service;
  fixed `<schedule>` cron expression or `<config_path>` (pair with
  `magento2-system-config`).

## Core Rules

- **Command name convention:** `{vendor_lower}:{module_lower}:{action}` (all lowercase,
  colon-separated). See `magento2-context/references/naming.md`.
- **Return codes:** use `Magento\Framework\Console\Cli::RETURN_SUCCESS` (0) and
  `Magento\Framework\Console\Cli::RETURN_FAILURE` (1). Never return bare `0`/`1`
  literals.
- **Delegate to a service.** The command or cron class must do no business logic itself —
  it constructs the call context and delegates to a constructor-injected `{ServiceName}`.
  Tests mock the service, not the command internals.
- **Area code.** When the command or cron job interacts with store models that require a
  scope (e.g. store emulation), set the area code via `\Magento\Framework\App\State`.
  The command class receives `State` via DI; never call `setAreaCode` twice.
- **Cron idempotency.** Every cron job must be safe to run twice in a row with the same
  outcome. Long-running jobs should acquire a mutex (e.g. a flag file or a cache-backed
  lock) to prevent overlap. See
  `${CLAUDE_SKILL_DIR}/references/cron-anatomy.md`.
- **Schedule variants:** use `<schedule>` for a literal cron expression
  (`*/5 * * * *`); use `<config_path>` to read the expression from admin config (pair
  with `magento2-system-config` to add the field). Default cron group is `default`.
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2
  coding standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the
  gate. See `magento2-context/references/php-coding-style.md`.
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `magento2-context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture the
JSON as `{ctx}`. Abort if `{ctx.magento_root}` is unresolved.

**Hard stop if the target module does not exist.** Offer `magento2-module-create` and
do not scaffold into a non-existent module.

### Phase 1 — Resolve Inputs

Ask for any missing values in one batch.

**Command mode**

| Input | Default | Notes |
|-------|---------|-------|
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Command class name | (ask) | PascalCase, e.g. `SyncOrdersCommand`; placed in `Console/Command/` |
| Command name (CLI) | (ask) | `{vendor_lower}:{module_lower}:{action}`, e.g. `acme:orders:sync` |
| Command description | (ask) | Short description shown in `bin/magento list` |
| Arguments | (ask) | Zero or more: name, required (yes/no), description |
| Options | (ask) | Zero or more: name, shortcut, mode (value/flag), description |
| Service FQCN | (ask) | The injected service class this command delegates to |

**Cron mode**

| Input | Default | Notes |
|-------|---------|-------|
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Cron job class name | (ask) | PascalCase, e.g. `SyncOrders`; placed in `Cron/` |
| Cron job name (XML) | (ask) | snake_case, unique across the Magento instance, e.g. `acme_orders_sync` |
| Schedule | (ask) | Literal cron expr (`*/5 * * * *`) OR config path (`acme_orders/cron/schedule`) |
| Cron group | `default` | Group id in `crontab.xml`; `default` covers most use cases |
| Service FQCN | (ask) | The injected service class this cron job delegates to |

See `${CLAUDE_SKILL_DIR}/references/console-command-anatomy.md` and
`${CLAUDE_SKILL_DIR}/references/cron-anatomy.md`.

### Phase 2 — Plan

Present every file to create or modify. Typical file sets per mode:

**Command mode:**
- `Console/Command/{CommandClass}.php`
- `etc/di.xml` (merge — `CommandList` registration)
- `Test/Unit/Console/Command/{CommandClass}Test.php`

**Cron mode:**
- `Cron/{CronJobName}.php`
- `etc/crontab.xml` (merge)
- `Test/Unit/Cron/{CronJobName}Test.php`

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing tests (RED).** Before generating implementation code, write
tests that express expected behaviour and confirm they fail for the right reason.

- **Command test** (`Test/Unit/Console/Command/{CommandClass}Test.php`): use
  `Symfony\Component\Console\Tester\CommandTester`; inject a mock `{ServiceName}`
  configured with `expects(self::once())`; run the command via `CommandTester::execute()`;
  assert `self::assertSame(0, $tester->getStatusCode())` (or
  `Magento\Framework\Console\Cli::RETURN_SUCCESS`); assert the output display contains the
  expected confirmation message.
- **Cron test** (`Test/Unit/Cron/{CronJobName}Test.php`): mock `{ServiceName}` with
  `expects(self::once())->method('execute')` (or the relevant method); call the cron
  `execute()` method; assert the return value (typically `void`/`$this`); call `execute()`
  a second time on a fresh instance to demonstrate idempotency-safety of the class itself.
  Use `self::assertNull` or equivalent — no `self::assertTrue(true)`.

Follow `magento2-context/references/tdd-discipline.md`. Run the 3A tests and confirm
they fail for the right reason (class-not-found, not a setup error).

**3B — Generate implementation (GREEN).** Write the minimal code to make the 3A tests
pass, using the templates:

- `${CLAUDE_SKILL_DIR}/templates/command-class.php`
- `${CLAUDE_SKILL_DIR}/templates/command-di.xml`
- `${CLAUDE_SKILL_DIR}/templates/cron-job-class.php`
- `${CLAUDE_SKILL_DIR}/templates/crontab.xml`
- `${CLAUDE_SKILL_DIR}/templates/test-command-unit.php`
- `${CLAUDE_SKILL_DIR}/templates/test-cron-unit.php`

See `${CLAUDE_SKILL_DIR}/references/console-command-anatomy.md`,
`${CLAUDE_SKILL_DIR}/references/cron-anatomy.md`, and
`${CLAUDE_SKILL_DIR}/references/pitfalls.md`.

### Phase 4 — Verify

- `php -l` on every generated `.php` file.
- `xmllint --noout` on every generated `.xml` file.
- Run the Phase 3A tests with `{ctx.runner} vendor/bin/phpunit` and confirm they now
  **pass** (they failed before 3B); run the module suite to confirm nothing else broke.
- **Apply the shared module-hygiene baseline (required).** After generating or modifying
  PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files
  that already carry it). When adding a `composer.json` `require` entry, resolve a
  **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.
- Run `magento2-module-review --diff` (gate: zero Critical/High findings).
- Consult `${CLAUDE_SKILL_DIR}/references/pitfalls.md` before declaring Phase 4 done.

### Phase 5 — Report

Write a brief Markdown report to
`{output_root}/cli-commands/{Vendor}_{Module}-{mode}-{slug}-{date}.md` listing:

- Mode (`command` or `cron`)
- Command/job name
- Files generated
- Test path + red→green evidence
- `bin/magento setup:upgrade` + `bin/magento cache:flush` commands
- (command mode) how to invoke: `bin/magento {CommandName} [args] [options]`
- (cron mode) how to trigger manually: `bin/magento cron:run --group={CronGroup}`

> **Docs may now be stale.** This change modified module code. Run
> `magento2-docs-generate --module={Vendor}_{Module}` to refresh the module's README,
> CHANGELOG, and `docs/*.md` (technical reference, guides, and API references as
> applicable).

## Inputs

```
/magento2-cli-command --mode=command --module=Acme_Orders --class=SyncOrdersCommand \
  --name=acme:orders:sync --service=Acme\Orders\Service\OrderSyncer

/magento2-cli-command --mode=cron --module=Acme_Orders --class=SyncOrders \
  --job=acme_orders_sync --schedule="*/15 * * * *" --service=Acme\Orders\Service\OrderSyncer

/magento2-cli-command --mode=command --module=Acme_Orders --class=SyncOrdersCommand \
  --name=acme:orders:sync --service=Acme\Orders\Service\OrderSyncer --docs-root=<path>
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Console/Command/{CommandClass}.php     # command mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/di.xml                             # command mode (merge)
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Console/Command/{CommandClass}Test.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Cron/{CronJobName}.php                 # cron mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/crontab.xml                        # cron mode (merge)
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Cron/{CronJobName}Test.php   # cron mode

{output_root}/cli-commands/{Vendor}_{Module}-{mode}-{slug}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/cli-commands/`; otherwise default to
`{ctx.docs_root}/cli-commands/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/console-command-anatomy.md` — `configure()`, `execute()`,
  return codes, `CommandList` DI registration.
- `${CLAUDE_SKILL_DIR}/references/cron-anatomy.md` — `crontab.xml` groups, `<schedule>` vs
  `<config_path>`, the `default` group, `cron:run`.
- `${CLAUDE_SKILL_DIR}/references/pitfalls.md` — delegate-to-service, area-code, cron
  idempotency/overlap, locking, long-running progress.
- `magento2-context/references/naming.md` — naming conventions.
- `magento2-context/references/tdd-discipline.md` — shared test-first RED/GREEN loop.
- `magento2-context/references/php-coding-style.md` — PER-CS + Magento coding style.
- `magento2-context/references/placeholder-schema.md` — token registry.
- `magento2-context/references/source-of-truth.md`: source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/command-class.php` → `Console/Command/{CommandClass}.php`
- `templates/command-di.xml` → `etc/di.xml` (merge)
- `templates/cron-job-class.php` → `Cron/{CronJobName}.php`
- `templates/crontab.xml` → `etc/crontab.xml` (merge)
- `templates/test-command-unit.php` → `Test/Unit/Console/Command/{CommandClass}Test.php`
- `templates/test-cron-unit.php` → `Test/Unit/Cron/{CronJobName}Test.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. Every token used must be in the
Registry there — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- All generated files pass `php -l` / `xmllint --noout`.
- Command name follows `{vendor_lower}:{module_lower}:{action}` pattern.
- `execute()` returns `Cli::RETURN_SUCCESS` or `Cli::RETURN_FAILURE` (never bare `0`/`1`).
- No business logic in the command or cron class — delegated to the injected service.
- Command test: `CommandTester` asserts status code 0 and expected output; service mock
  uses `expects(self::once())`.
- Cron test: service mock uses `expects(self::once())`; second invocation demonstrates
  class-level idempotency-safety; no `markTestIncomplete`, no `self::assertTrue(true)`.
- `magento2-module-review --diff` returns zero Critical/High findings.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| Before (if module absent) | `magento2-module-create` |
| Cron schedule from admin config | `magento2-system-config` |
| After | `magento2-module-review --diff` |
