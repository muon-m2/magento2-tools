---
name: magento2-eav-attribute
description:
    Add a Magento 2 EAV attribute (product, customer, customer-address, or category) via
    an idempotent data patch. Use when the user wants to add a product/customer/category
    attribute. Handles scope (global/website/store), input type, backend/source/frontend
    models, indexer registration, form/grid visibility, and admin section assignment.
    Produces a Setup/Patch/Data/ class that passes magento2-module-review. For non-EAV or bulk
    data seeding/migration use magento2-data-migration.
---

# Magento 2 EAV Attribute

Add a product, customer, customer-address, or category attribute via an idempotent data
patch with correct backend / source / frontend models, scope, store-view handling, and
indexer integration.

## Core Rules

- **One attribute per patch.** Each `Add{Code}Attribute.php` adds exactly one attribute.
  Bundling multiple attributes per patch makes failures harder to recover from.
- **Idempotent.** Re-running `setup:upgrade` must not duplicate the attribute. Use
  `EavSetup::getAttribute()` check before adding.
- **`getDependencies()` always present.** Even when empty, the method must be implemented.
- **Use the matching Setup factory.** Product → `EavSetupFactory`; Customer →
  `CustomerSetupFactory`; etc. Mixing factories breaks the patch.
- **No legacy `Setup/InstallData.php`.** Use `Setup/Patch/Data/` only.
- **Generate companions only when needed.** Source model only for select/multiselect;
  backend model only for date/image/price/multiselect/non-trivial; frontend model only
  when explicitly requested.
- **Test-first for the attribute effect.** Write the failing integration test before the patch
  (red → green → refactor) and **watch it fail for the right reason**. It asserts the attribute
  exists after the patch runs with the declared **scope** (`is_global`), `frontend_input`, and
  any backend/source model wiring — plus **idempotency** (patch runs twice → no duplicate, no
  error). Behaviour-bearing source/backend models get a test-first **unit** test (e.g. the source
  model's `toOptionArray()`). See `magento2-context/references/tdd-discipline.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2 coding
  standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the gate. See
  `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`.

### Phase 1 — Resolve Inputs

Ask for any missing values:

| Input                             | Default | Notes                                                                         |
|-----------------------------------|---------|-------------------------------------------------------------------------------|
| Entity type                       | (ask)   | `product`, `customer`, `customer_address`, `category`                         |
| Module to host the patch          | (ask)   | Existing `{Vendor}_{Module}` or new                                           |
| Attribute code                    | (ask)   | snake_case, ≤ 30 chars                                                        |
| Attribute label                   | (ask)   | Human-readable                                                                |
| Input type                        | text    | text, textarea, select, multiselect, date, boolean, price, image, media_image |
| Scope                             | store   | global, website, store                                                        |
| Required                          | false   | true/false                                                                    |
| Source model                      | none    | Required if select/multiselect                                                |
| Backend model                     | none    | Required for multiselect, image, date, price                                  |
| Frontend model                    | none    | Optional                                                                      |
| Used in product listing           | false   | Triggers flat-table inclusion                                                 |
| Used for sorting                  | false   | Triggers flat-table inclusion                                                 |
| Filterable in catalog search      | false   | Layered nav                                                                   |
| Searchable                        | false   | Catalog search index                                                          |
| Visible on storefront             | true    | Triggers system attribute group assignment                                    |
| Apply to product types            | all     | Restrict to simple, configurable, etc.                                        |
| Form / grid visibility (customer) | varies  | `is_used_in_grid`, `is_visible_in_grid` etc.                                  |

See `references/entity-types.md`, `references/input-types.md`, `references/scope-rules.md`.

### Phase 2 — Plan

Present the file plan:

- `Setup/Patch/Data/Add{AttributeCode}Attribute.php`
- Optionally: source model `Model/Source/{AttributeCode}.php`
- Optionally: backend model `Model/Attribute/Backend/{AttributeCode}.php`
- Optionally: frontend model `Model/Attribute/Frontend/{AttributeCode}.php`
- Optionally: indexer/system attribute registration in `etc/indexer.xml`
- Optionally: DI binding for source model in `etc/di.xml`

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing test (RED).** Before any patch code, add an integration test under
`Test/Integration/` that loads the attribute (via the entity's attribute repository / EAV config)
and asserts it exists with the declared scope, input type, and backend/source wiring, plus
idempotency (running the patch twice does not duplicate or error). Follow
`magento2-context/references/tdd-discipline.md` and the integration patterns in
`magento2-test-generate/references/integration-patterns.md`. Run it and **confirm it fails for
the right reason** (attribute absent), not a setup error. If no Magento test DB is available,
follow the *tiered fallback*: for an attribute with a behavioural source/backend model, write a
test-first unit test of that model; record the integration gap in the Phase 5 report.

**3B — Generate the patch (GREEN).** Write the minimal patch to turn 3A green, using the
entity-specific template:

- `templates/eav-add-product-attribute-patch.php`
- `templates/eav-add-customer-attribute-patch.php`
- `templates/eav-add-customer-address-attribute-patch.php`
- `templates/eav-add-category-attribute-patch.php`

Plus companion templates as needed:

- `templates/source-model.php`
- `templates/backend-model.php`
- `templates/frontend-model.php`

### Phase 4 — Verify

- `php -l` on every generated file.
- Run the Phase 3A test with `{ctx.runner} vendor/bin/phpunit` and confirm it now **passes**
  (it failed before 3B); run the affected module's suite to confirm nothing else broke.
- `composer validate` if composer.json was modified.
- Verify dependencies in `getDependencies()` reference existing classes.
- **Apply the shared module-hygiene baseline (required).** After generating or modifying PHP
  files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files that
  already carry it). When adding a `composer.json` `require` entry, resolve a **bounded**
  constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.

### Phase 5 — Report

Brief Markdown saved to `{output_root}/eav-attributes/{Vendor}_{Module}-{code}-{date}.md`:

- Files generated
- Test path + red→green evidence (or the recorded integration gap if no test DB was available)
- Migration command: `bin/magento setup:upgrade`
- Reindex hint if attribute is searchable / filterable
- Cache flush hint

> **Docs may now be stale.** This change modified module code. Run
> `magento2-docs-generate --module={Vendor}_{Module}` to refresh the module's README,
> CHANGELOG, and `docs/*.md` (technical reference, guides, and API references as
> applicable).

## Inputs

```
/magento2-eav-attribute --entity=product --code=acme_color --label="Acme Color" --type=select --module=Acme_Catalog [--docs-root=<path>]
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Setup/Patch/Data/Add{Code}Attribute.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Source/{Code}.php          # if applicable
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Attribute/Backend/{Code}.php # if applicable
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration/.../Add{Code}AttributeTest.php  # test-first (Phase 3A)

{output_root}/eav-attributes/{Vendor}_{Module}-{code}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/eav-attributes/`; otherwise default to
`{ctx.docs_root}/eav-attributes/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `references/entity-types.md` — per-entity-type input map.
- `references/input-types.md` — each input type's required backend/source model.
- `references/scope-rules.md` — global vs website vs store semantics.
- `references/source-model-patterns.md` — standard source model implementations.
- `references/backend-model-patterns.md` — standard backend model implementations.
- `references/frontend-impact.md` — listing, sorting, search, layered nav.
- `magento2-context/references/tdd-discipline.md` — shared test-first loop applied in Phase 3A
  (integration patterns: `magento2-test-generate/references/integration-patterns.md`).

## Templates

- `templates/eav-add-product-attribute-patch.php`
- `templates/eav-add-customer-attribute-patch.php`
- `templates/eav-add-customer-address-attribute-patch.php`
- `templates/eav-add-category-attribute-patch.php`
- `templates/source-model.php`
- `templates/backend-model.php`
- `templates/frontend-model.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. This skill's templates use the
`{Vendor}` / `{Module}` / `{Entity}` convention (both that and the module-create
`{ModuleName}` / `{EntityName}` convention are registered and accepted). Every token used
must be in the Registry there — `tests/test-placeholder-tokens.sh` enforces it.

(Near-identical EAV patch templates also exist in `magento2-module-create/templates/`
(`eav-add-*-attribute-patch.php`). They are **not** identical: this skill's copies are the
canonical ones for EAV work because they add the `getAttribute()` idempotency short-circuit
and the `try/finally` around `startSetup()/endSetup()`. Prefer this skill's templates; the
module-create copies are the simpler scaffolding variant. Single-sourcing the two sets is
tracked as a follow-up.)

## Acceptance Criteria

- Generated patch is idempotent.
- An integration test asserting the attribute's scope/input-type/wiring **and** idempotency was
  written and **watched to fail** before the patch existed, and passes after (or, when no test DB
  is available, a test-first unit test covers a behavioural source/backend model and the
  integration gap is recorded).
- Patch implements `DataPatchInterface` and uses the correct `*SetupFactory` for the
  entity type.
- Source/backend/frontend model is generated only when actually required.
- Generated patch passes `magento2-module-review` with zero Critical/High findings.

## Common Pitfalls Handled

| Pitfall                                            | How the skill avoids it                      |
|----------------------------------------------------|----------------------------------------------|
| Forgetting `getDependencies()` returns             | Always emitted, even when empty              |
| `addAttribute` without `apply_to` for product type | Asked in Phase 1                             |
| `is_global` set wrong                              | Asked in Phase 1; default `store`            |
| Missing DI for source model                        | Generated when source model used             |
| Missing `is_used_in_grid` / `is_visible_in_grid`   | Asked in Phase 1                             |
| Legacy `Setup/InstallData.php`                     | Skill refuses; uses `Setup/Patch/Data/` only |

## Related Skills

| Phase    | Skill                                                                         |
|----------|-------------------------------------------------------------------------------|
| 0        | `magento2-context`                                                            |
| (caller) | `magento2-feature-implement` Phase 5 — when blueprint declares EAV attributes |
