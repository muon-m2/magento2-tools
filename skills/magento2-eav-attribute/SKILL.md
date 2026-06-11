---
name: magento2-eav-attribute
description:
    Add a Magento 2 EAV attribute (product, customer, customer-address, or category) via
    an idempotent data patch. Use when the user wants to add a product/customer/category
    attribute. Handles scope (global/website/store), input type, backend/source/frontend
    models, indexer registration, form/grid visibility, and admin section assignment.
    Produces a Setup/Patch/Data/ class that passes magento2-module-review.
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

### Phase 3 — Generate

Use the entity-specific template:

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
- `composer validate` if composer.json was modified.
- Verify dependencies in `getDependencies()` reference existing classes.

### Phase 5 — Report

Brief Markdown saved to `.docs/eav-attributes/{Vendor}_{Module}-{code}-{date}.md`:

- Files generated
- Migration command: `bin/magento setup:upgrade`
- Reindex hint if attribute is searchable / filterable
- Cache flush hint

## Inputs

```
/magento2-eav-attribute --entity=product --code=acme_color --label="Acme Color" --type=select --module=Acme_Catalog
```

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Setup/Patch/Data/Add{Code}Attribute.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Source/{Code}.php          # if applicable
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Attribute/Backend/{Code}.php # if applicable

.docs/eav-attributes/{Vendor}_{Module}-{code}-{date}.md
```

## Reference Files

- `references/entity-types.md` — per-entity-type input map.
- `references/input-types.md` — each input type's required backend/source model.
- `references/scope-rules.md` — global vs website vs store semantics.
- `references/source-model-patterns.md` — standard source model implementations.
- `references/backend-model-patterns.md` — standard backend model implementations.
- `references/frontend-impact.md` — listing, sorting, search, layered nav.

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
