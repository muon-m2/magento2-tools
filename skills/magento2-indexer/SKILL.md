---
name: magento2-indexer
description:
    Scaffold a custom Magento 2 indexer + materialized view (mview) on an existing
    module — `indexer.xml`, `mview.xml` subscriptions, an `ActionInterface` indexer
    (executeFull/executeList/executeRow) + Mview `ActionInterface` (execute), delegating
    to a batched action class. Use for 'add a custom index'. For a new module use
    `magento2-module-create`; to review/diagnose existing indexer performance use
    `magento2-performance-audit`.
---

# Magento 2 Indexer / Mview Scaffold

Scaffold a custom indexer and materialized view (mview) onto an **existing** Magento 2
module. Produces `indexer.xml`, `mview.xml`, an indexer class (implements both
`ActionInterface` interfaces), and a dedicated action/builder class that owns all reindex
logic.

## Core Rules

- **Indexer id convention:** `{vendor_lower}_{module_lower}_{entity}` (all lowercase,
  underscore-separated). See `magento2-context/references/naming.md`.
- **`view_id` matches the indexer id.** The `<view id>` in `mview.xml` must equal the
  `<indexer id>` in `indexer.xml` — mismatch is the #1 mview wiring bug.
- **Two ActionInterfaces.** The indexer class implements BOTH
  `Magento\Framework\Indexer\ActionInterface` (methods `executeFull`, `executeList`,
  `executeRow`) AND `Magento\Framework\Mview\ActionInterface` (method `execute`). Import
  them with distinct short names via `use`:
  ```php
  use Magento\Framework\Indexer\ActionInterface;
  use Magento\Framework\Mview\ActionInterface as MviewActionInterface;
  ```
  This avoids the fatal name clash without FQCNs in the class body.
- **Delegate all logic.** The indexer class must do **zero** reindex work. It only
  delegates to a constructor-injected action class (named `{IndexerName}Action`). All SQL
  and batching logic lives in the action class. Tests mock the action, not the indexer.
- **Batching is mandatory.** `executeList(array $ids)` and `execute(array $ids)` (Mview)
  must process ids in configurable-size chunks — never load all at once. Use
  `array_chunk($ids, self::BATCH_SIZE)`.
- **Idempotency.** Full reindex (`executeFull`) must rebuild from scratch such that running
  it twice produces identical index data. Partial reindex must be safe to re-run on the
  same id set. The action class achieves this via a delete-then-insert pattern per batch.
- **Mview subscriptions** watch the SOURCE table(s). When a row changes in the source
  table, Magento records the changed entity id in the mview changelog table; the scheduled
  indexer mode picks those up and calls `execute([ids])`. Choose the column that holds
  the entity primary key as `entity_column`.
- **Two indexer modes** (set per-deployment via `bin/magento indexer:set-mode`):
  - `realtime` ("Update on Save") — Magento calls `executeRow($id)` or `executeList($ids)`
    synchronously after a save.
  - `schedule` ("Update by Schedule") — saves write to the mview changelog; cron calls
    `execute($ids)` on the batch.
- **Dimensions / sharding** (Adobe Commerce only, advanced surface) — the Indexer
  framework supports `<fieldset>` dimensions for sharding by store/customer-group. Do NOT
  scaffold dimensions by default; note the feature exists for Commerce deployments that
  need horizontal index sharding.
- **PHPCS / coding style.** Generated PHP follows PER-CS 3.0 as the baseline with the
  Magento 2 coding standard taking precedence; `--standard=Magento2` is the gate.
  `declare(strict_types=1)` on every file; no `final` on any class.
  See `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture the
JSON as `{ctx}`. Abort if `{ctx.magento_root}` is unresolved.

**Hard stop if the target module does not exist.** Check
`{ctx.magento_root}/app/code/{Vendor}/{Module}/registration.php`. If absent, offer
`magento2-module-create` and abort — do not scaffold into a non-existent module.

### Phase 1 — Resolve Inputs

Ask for any missing values in one batch.

| Input | Default | Notes |
|-------|---------|-------|
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Indexer class name | (ask) | PascalCase, e.g. `ProductStock`; placed in `Model/Indexer/` |
| Indexer id | (ask) | `{vendor_lower}_{module_lower}_{entity}`, e.g. `acme_catalog_productstock` |
| Indexer title | (ask) | Human-readable, shown in admin (e.g. `Acme Product Stock`) |
| Indexer description | (ask) | One-sentence description shown in admin |
| Entity being indexed | (ask) | Conceptual entity label, e.g. `product_stock` |
| Source table(s) | (ask) | DB table(s) to subscribe to in mview, e.g. `cataloginventory_stock_item` |
| Entity id column | (ask) | Column in the source table holding the entity PK, e.g. `product_id` |
| Target index table | (ask) | Destination table the action writes to, e.g. `acme_catalog_productstock_index` |

See `${CLAUDE_SKILL_DIR}/references/indexer-anatomy.md` and
`${CLAUDE_SKILL_DIR}/references/mview-subscriptions.md`.

### Phase 2 — Plan

Present every file to create or modify. Typical file set:

- `etc/indexer.xml` (merge)
- `etc/mview.xml` (merge)
- `Model/Indexer/{IndexerName}.php`
- `Model/Indexer/{IndexerName}Action.php`
- `Test/Unit/Model/Indexer/{IndexerName}Test.php`

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing tests (RED).** Before generating implementation code, write
the unit test asserting delegation behaviour. Use mocks — no Magento bootstrap required.

The test (`Test/Unit/Model/Indexer/{IndexerName}Test.php`) must:

- Mock the `{IndexerName}Action` class; configure with `expects(self::once())` for each
  delegation method.
- Assert `executeFull()` delegates to `action->executeFull()` — no ids.
- Assert `executeList([1, 2, 3])` delegates to `action->execute([1, 2, 3])` with the
  exact id array.
- Assert `executeRow(42)` delegates to `action->execute([42])` — wraps the single id.
- Assert Mview `execute([1, 2])` delegates to `action->execute([1, 2])` with the exact
  id array.
- Demonstrate idempotency-safety at the class level: instantiate a fresh indexer with a
  fresh mock configured `expects(self::once())`; call `executeFull()` twice on two
  different instances to show the class itself has no hidden state that breaks a repeat
  call — no `self::assertTrue(true)`, no `markTestIncomplete`.

Follow `magento2-context/references/tdd-discipline.md`. Run the 3A tests and confirm they
fail for the right reason (class-not-found, not a PHPUnit setup error).

**3B — Generate implementation (GREEN).** Write the minimal code to make the 3A tests
pass, using the templates:

- `${CLAUDE_SKILL_DIR}/templates/indexer.xml`
- `${CLAUDE_SKILL_DIR}/templates/mview.xml`
- `${CLAUDE_SKILL_DIR}/templates/indexer-class.php`
- `${CLAUDE_SKILL_DIR}/templates/indexer-action.php`
- `${CLAUDE_SKILL_DIR}/templates/test-indexer-unit.php`

See `${CLAUDE_SKILL_DIR}/references/indexer-anatomy.md`,
`${CLAUDE_SKILL_DIR}/references/mview-subscriptions.md`, and
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
`{output_root}/indexers/{Vendor}_{Module}-{indexer_id}-{date}.md` listing:

- Indexer id and title
- Files generated
- Test path + red→green evidence
- `bin/magento setup:upgrade` + `bin/magento cache:flush` commands
- How to trigger a full reindex: `bin/magento indexer:reindex {indexer_id}`
- How to check status: `bin/magento indexer:status`
- How to switch mode: `bin/magento indexer:set-mode [realtime|schedule] {indexer_id}`

## Inputs

```
/magento2-indexer --module=Acme_Catalog --class=ProductStock \
  --id=acme_catalog_productstock --title="Acme Product Stock" \
  --source-table=cataloginventory_stock_item --id-column=product_id \
  --target-table=acme_catalog_productstock_index [--docs-root=<path>]
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/indexer.xml             (merge)
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/mview.xml               (merge)
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Indexer/{IndexerName}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Indexer/{IndexerName}Action.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Model/Indexer/{IndexerName}Test.php

{output_root}/indexers/{Vendor}_{Module}-{indexer_id}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/indexers/`; otherwise default to
`{ctx.docs_root}/indexers/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/indexer-anatomy.md` — `indexer.xml` structure, the two
  ActionInterfaces and their methods, the indexer→action delegation pattern,
  `indexer:reindex`/`indexer:status`/`indexer:set-mode`.
- `${CLAUDE_SKILL_DIR}/references/mview-subscriptions.md` — `mview.xml` structure,
  subscriptions, choosing the source table and entity_column, the `indexer` mview group.
- `${CLAUDE_SKILL_DIR}/references/pitfalls.md` — full vs partial reindex, batching,
  idempotency, `executeRow` overhead, realtime vs schedule mode, dimensions caveat,
  changelog table growth.
- `magento2-context/references/naming.md` — naming conventions.
- `magento2-context/references/tdd-discipline.md` — shared test-first RED/GREEN loop.
- `magento2-context/references/php-coding-style.md` — PER-CS + Magento coding style.
- `magento2-context/references/placeholder-schema.md` — token registry.

## Templates

- `templates/indexer.xml` → `etc/indexer.xml` (merge)
- `templates/mview.xml` → `etc/mview.xml` (merge)
- `templates/indexer-class.php` → `Model/Indexer/{IndexerName}.php`
- `templates/indexer-action.php` → `Model/Indexer/{IndexerName}Action.php`
- `templates/test-indexer-unit.php` → `Test/Unit/Model/Indexer/{IndexerName}Test.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. Every token used must be in the
registry — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- All generated files pass `php -l` / `xmllint --noout`.
- Indexer id follows `{vendor_lower}_{module_lower}_{entity}` pattern.
- `view_id` in `mview.xml` equals `id` in `indexer.xml`.
- The indexer class implements both ActionInterfaces; name clash resolved via
  `use ... as MviewActionInterface`.
- The indexer class contains zero reindex logic — all delegation to the action class.
- The action class batches id sets via `array_chunk`; full reindex is idempotent
  (delete-then-insert).
- Unit test uses `expects(self::once())` for every delegation assertion; no
  `markTestIncomplete`, no `self::assertTrue(true)`.
- `magento2-module-review --diff` returns zero Critical/High findings.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| Before (if module absent) | `magento2-module-create` |
| After | `magento2-module-review --diff` |
| Diagnose existing indexer perf | `magento2-performance-audit` |
