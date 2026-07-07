---
name: magento2-data-migration
description:
    Generate Magento 2 data migration code — data patches for fixed seeds, importers for
    CSV/JSON sources, and transformation scripts. Use when the user needs to seed reference
    data, migrate from Magento 1, import bulk data from external systems, or restructure
    existing data idempotently. Produces idempotent patches that pass magento2-module-review. For
    adding an EAV attribute use magento2-eav-attribute.
---

# Magento 2 Data Migration

Generate data patches, importer services, and transformation scripts.

## Core Rules

- **Idempotent.** Re-running `setup:upgrade` must NOT duplicate data. Check for existing
  state before inserting.
- **DataPatchInterface only.** No legacy `Setup/InstallData.php` or `UpgradeData.php`.
- **Chunked for bulk.** Imports of > 100 rows must process in batches of ≤ 500.
- **Transactional for transformations.** SELECT → INSERT → DELETE wrapped in a single
  DB transaction (where possible).
- **Reversible when feasible.** Patches that delete data must document the rollback path
  (or refuse to delete without `--allow-destructive`).
- **Test-first for the data effect.** Write the failing integration test before the patch body
  (red → green → refactor) and **watch it fail for the right reason**. The test asserts the
  post-migration state and, critically, **idempotency** (apply twice → identical state). The
  patch exists only to turn that test green. See `magento2-context/references/tdd-discipline.md`.
  A patch is exempt only when it is pure config with no data effect — document why.
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2 coding
  standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the gate. See
  `magento2-context/references/php-coding-style.md`.
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `magento2-context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`.

### Phase 1 — Plan

Determine migration class:

| Class | When |
|-------|------|
| Fixed seed | Small, known data (< 100 rows hard-coded in PHP) |
| Bulk import | CSV/JSON, > 100 rows from an external source |
| Transformation | Move/rename existing data inside Magento |

Ask the user for:
- Data source (file path, API endpoint, M1 DB connection details)
- Target tables / entities
- Idempotency strategy (hash, unique constraint, lookup-then-insert)
- Whether rollback is required

### Phase 2 — Test First, then Generate

**2A — Write the failing test (RED).** Before any patch code, add an integration test under
`Test/Integration/` that asserts the post-migration state **and idempotency** (run the patch
twice → identical rows, no duplicates, no error). Start from
`magento2-test-generate/templates/test-integration-data-patch.php` and follow
`magento2-context/references/tdd-discipline.md`. Run it and **confirm it fails for the right
reason** (data absent / patch class missing) — not a setup or missing-class error. If no Magento
test DB is available, follow the *tiered fallback* in `tdd-discipline.md`: write a test-first
**unit** test of the importer's idempotency guard (lookup-then-insert) instead, and record the
integration gap in the Phase 4 report.

**2B — Generate the patch (GREEN).** Write the minimal patch needed to turn 2A green:

#### Fixed seed

- `Setup/Patch/Data/{Name}.php` with the data inline.

#### Bulk import

- `Setup/Patch/Data/{Name}.php` invoking…
- `Service/Importer/{Name}Importer.php` — chunked processing, idempotency checks
- Optional `Console/Command/{Name}Command.php` — CLI entry point
  (`bin/magento {vendor}:{module}:import [--dry-run]`)

#### Transformation

- `Setup/Patch/Data/{Name}.php` with SELECT → INSERT → DELETE inside a transaction.
- Idempotency: check whether destination already has the migrated row before inserting.

**2C — Refactor.** With the test green, tidy only what you touched; keep it green.

### Phase 3 — Verify

- `php -l` on each file.
- Run the Phase 2A test with `{ctx.runner} vendor/bin/phpunit` and confirm it now **passes**
  (it failed before 2B). Run the affected module's suite to confirm nothing else broke.
- Dry-run: optional `--dry-run` flag on generated CLI command outputs what would be
  imported without writing.
- **Apply the shared module-hygiene baseline (required).** After generating or modifying
  PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files
  that already carry it). When adding a `composer.json` `require` entry, resolve a
  **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.

### Phase 4 — Report

Save to `{output_root}/migrations/{name}-{date}.md`:
- Source described
- Target tables / entities
- Idempotency strategy
- Test path + red→green evidence (or the recorded integration gap if a test DB was unavailable)
- Re-run safety statement
- Rollback statement (if feasible)
- Migration command for the user to run

> **Docs may now be stale.** This change modified module code. Run
> `magento2-docs-generate --module={Vendor}_{Module}` to refresh the module's README,
> CHANGELOG, and `docs/*.md` (technical reference, guides, and API references as
> applicable).

## Inputs

```
/magento2-data-migration --type=seed|import|transform [source flags] [--docs-root=<path>]
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Setup/Patch/Data/{Name}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Service/Importer/{Name}Importer.php        # if import
{ctx.magento_root}/app/code/{Vendor}/{Module}/Console/Command/{Name}Command.php          # if CLI
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration/Setup/Patch/Data/{Name}Test.php  # test-first (Phase 2A)

{output_root}/migrations/{name}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/migrations/`; otherwise default to
`{ctx.docs_root}/migrations/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `references/data-patch-rules.md` — DataPatchInterface idempotency rules.
- `references/importer-patterns.md` — chunked import patterns.
- `references/m1-to-m2-map.md` — common Magento 1 → 2 transformations.
- `references/idempotency-strategies.md` — hash-based, unique-constraint, lookup-then-insert.
- `references/rollback-strategies.md` — when rollback is feasible; how to implement.
- `magento2-context/references/tdd-discipline.md` — shared test-first loop; the Phase 2A test
  reuses `magento2-test-generate/templates/test-integration-data-patch.php` as its skeleton.
- `magento2-context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/data-patch-fixed-seed.php`
- `templates/data-patch-bulk-import.php`
- `templates/data-patch-transformation.php`
- `templates/importer-service.php`
- `templates/import-cli-command.php`

## Acceptance Criteria

- All generated patches implement `DataPatchInterface` and `getDependencies()`.
- All patches are idempotent.
- A test asserting **idempotency** (apply twice → identical state) was written and **watched to
  fail** before the patch existed, and passes after (integration when a test DB is available;
  otherwise a test-first unit test of the idempotency guard, with the integration gap recorded).
- For bulk imports, processing is chunked (default 500 rows).
- For transformations, source data is preserved until destination is verified.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (after Phase 2) | `magento2-module-review` for the affected module |
