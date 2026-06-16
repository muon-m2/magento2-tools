# New project guide

A step-by-step path for adopting `magento2-tools` on a **new Magento 2 project** (or a
project that has never used the toolkit) — from installation to a scaffolded, reviewed,
tested, deployed, and releasable first module.

Times are rough; most steps are minutes, not hours.

## Step 0 — Prerequisites and installation

You need a Magento 2 codebase (fresh `composer create-project` is fine; a running
instance is *not* required for most steps) and Claude Code. Install the plugin:

```
/plugin marketplace add muon-m2/magento2-tools
/plugin install magento2-tools@muon-m2 --scope user
```

For the whole team, commit `.claude/settings.json` to the project so the plugin is
offered automatically on folder trust — see [Getting started](getting-started.md#install).

## Step 1 — Declare your conventions in CLAUDE.md

The skills read your project's `CLAUDE.md` for a handful of hints. The single most
useful line to add on day one is the vendor prefix:

```markdown
Vendor prefix: **Acme**
```

Without it, the context resolver falls back to probing `app/code/` (empty on a new
project) and will ask you. With it, every scaffolded module, table name, ACL ID, and
route lands under the right namespace from the first run.

Other recognized hints (all optional — see [Configuration](configuration.md)):

| CLAUDE.md line | Effect |
|----------------|--------|
| `Vendor prefix: **Acme**` | Vendor for all generated code |
| `Allow smoke on production: true` | Lets feature smoke tests run against production (default: refused) |
| `Feature implement: per-task commits = on` | One focused git commit per completed feature task |
| `Feature implement: tdd = on` | Implement feature behaviour test-first (red → green → refactor); default off |

## Step 2 — Environment overrides (only if detection needs help)

The context resolver auto-detects the repo layout (`./app/code` vs `src/app/code`) and
the runner (bare PHP vs Docker, including compose service-name matching). For
non-standard setups, commit a `.claude/m2.json`:

```json
{ "php_container": "my-php-container", "magento_root": "src" }
```

or export `M2_PHP_CONTAINER` / `M2_MAGENTO_ROOT` (env wins over file). A configured
container that is not running falls through to generic detection, and changing any
override busts the resolver cache automatically.

## Step 3 — Validate the context

```
Resolve the Magento 2 project context
```

Check the emitted JSON: `vendor`, `magento_root`, `runner_kind`, `magento_cli`,
`edition`, `magento_version`, `php_version`, `theme.frontend`, and the `tools` block.
Every value carries its `resolution_source` — if something is wrong, fix the source
(CLAUDE.md hint or override) rather than working around it. The result is cached in
`.claude/.cache/magento2-context.json` and reused by every other skill.

Tip: add `.claude/.cache/` to `.gitignore`; the cache is per-machine.

## Step 4 — Scaffold your first module

For a real module, declare its **surfaces** — the toolkit's unit of scaffolding:

```
Create a module OrderExport with persistence, service contracts, a REST API and admin config
```

`magento2-module-create` maps that to surfaces (`core` is always included;
`persistence`, `service_contracts`, `rest_api`, `admin_config` here), presents a module
profile (vendor, path, surfaces, estimated file count) for confirmation, then generates
surface-by-surface from templates. What you get, and can rely on:

- Every file passes the 12 `magento2-module-review` categories **on creation** — typed
  constructors, strict types, PHPDoc on every public method, escaped templates,
  form-key-validated POST controllers, ACL-protected admin config, snake_case
  `{vendor}_{module}_{entity}` tables, DI preferences wired.
- Only declared surfaces are created — no empty placeholder directories.
- Everything is linted (`php -l`, `xmllint`, `composer validate`) before the skill
  reports done, and the creation checklist is shown per category.
- Nothing touches the database: `setup:upgrade` / whitelist generation are offered as
  explicit next steps, typically via `magento2-deploy`.

For a throwaway experiment, say `quick` or `skeleton` to get core files only.

## Step 5 — First deploy (local)

```
/magento2-tools:magento2-deploy --env=local Acme_OrderExport
```

Pre-flight checks run first (module files, composer validate, unit tests,
`setup:db:status`, disk space); you approve the printed plan; then
`module:enable` → `setup:upgrade` → whitelist generation for persistence modules →
`cache:flush` → `indexer:status`, with per-step capture and rollback recipes on
failure. The deploy report lands in `.docs/deployments/`.

## Step 6 — Your first feature, end to end

Now do a real slice of work the orchestrated way:

```
Implement a feature: export completed orders nightly as CSV to var/export, with an
admin config screen for enabling it and choosing the export fields
```

`magento2-feature-implement` will walk you through blueprint → (your approval) →
module schema → task plan → (your approval) → execution with per-task reviews →
unit tests + coverage → smoke battery → final report. Budget for reading the blueprint
carefully — it is the contract for everything that follows, and changing it later costs
more than fixing it at the gate.

Everything lands in `.docs/{FeatureName}/` — blueprint, resumable plan, task records,
report. If a session is interrupted, *"resume ./.docs/{FeatureName}"* picks up exactly
where it stopped.

To make the orchestrator implement behaviour **test-first**, add `--tdd` (or set
`Feature implement: tdd = on` in `CLAUDE.md` to make it the team default). The acceptance
criteria in the plan then become failing tests written before each behaviour class, while
scaffolding and config stay generated-then-covered. It's the same red → green → refactor
loop `magento2-bug-fix` already uses — see
[Flows and scenarios](flows-and-scenarios.md#feature-implementation-flow).

See [Flows and scenarios](flows-and-scenarios.md#feature-implementation-flow) for the
full phase diagram.

## Step 7 — Establish the testing baseline

`magento2-test-generate` is the **backfiller** for code that already exists. If you
hand-wrote code outside the orchestrator (or are adopting the toolkit on a module that has
no tests), backfill it:

```
/magento2-tools:magento2-test-generate Acme_OrderExport
```

Discovery shows what's missing per test type (unit / integration / API / Jasmine /
MFTF); you approve the plan; generated tests contain real assertions and are run before
the skill reports done. Coverage reports go to `.docs/tests/`.

For *new* work going forward, prefer **test-first** instead of backfilling: bug fixes are
test-first always, EAV attributes and data patches are test-first by default, and
feature work is test-first under `--tdd` (Step 6). Backfilling stays the right tool for
existing, untested code.

## Step 8 — Wire CI

Three integrations pay off immediately:

1. **Deploy gate** — run pre-flight validation without deploying:

   ```
   /magento2-tools:magento2-deploy --validate-only --strict --env=local Acme_OrderExport
   ```

   Exit 0/1 plus a machine-readable `.docs/deployments/{ts}-local.json` with
   `"mode": "validate-only"`.

2. **Findings as SARIF** — reviews and audits emit SARIF 2.1.0 alongside JSON; upload
   to GitHub Code Scanning to get findings as PR annotations.

3. **Conventional commits** — adopt `feat:` / `fix:` / `BREAKING CHANGE:` from the
   first commit. `magento2-release` derives version bumps from them; without the
   convention you'll be overriding versions by hand forever.

## Step 9 — First release

When the module is worth versioning:

```
/magento2-tools:magento2-release Acme_OrderExport
```

Validate (via the deploy pre-flight) → version proposal from commits → `composer.json`
+ `CHANGELOG.md` bump → module-prefixed tag (`Acme_OrderExport-1.0.0`) → push only
after you type `release` → optional GitHub Release. Multi-module repos work naturally:
tags are module-prefixed, each module keeps its own `composer.json` and `CHANGELOG.md`,
one module per release invocation.

## New-project checklist

- [ ] Plugin installed; `.claude/settings.json` committed for the team
- [ ] `CLAUDE.md` has `Vendor prefix: **…**`
- [ ] `.claude/m2.json` committed if layout/runner detection needs help
- [ ] Context resolved and verified (`vendor`, `runner_kind`, `magento_cli`, `tools`)
- [ ] `.claude/.cache/` in `.gitignore`
- [ ] First module scaffolded and deployed locally
- [ ] Quality tools installed as the project matures (`phpcs` + `magento/magento-coding-standard`, `phpstan`, `phpunit`) — skills use them automatically once present
- [ ] CI: `--validate-only` deploy gate + SARIF upload
- [ ] Conventional commits adopted
- [ ] Decide on test-first: set `Feature implement: tdd = on` in `CLAUDE.md` to make feature behaviour test-first by default (bug-fix / EAV / data patches already are)
- [ ] Decide whether `.docs/` (skill reports) is committed or ignored — committing it
      gives the team a shared history of blueprints, RCAs, deploys, and audits
