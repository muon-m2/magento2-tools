---
name: magento2-adminhtml-listing
description:
    Generate a Magento 2 adminhtml UI-component listing/grid — the declarative
    `ui_component/{entity}_listing.xml` plus its DataProvider, columns, actions column, and mass
    actions, wired to an existing edit form. Use when the user wants to add or scaffold an admin
    grid, data grid, listing page, grid columns, filters, mass actions, or an actions column in
    the Magento admin. Pairs with magento2-adminhtml-form (the edit form); for the form itself use
    magento2-adminhtml-form. Detects edition and flags Commerce-only grid features. Produces files
    that pass magento2-module-review with zero Critical/High findings.
---

# Magento 2 Adminhtml Listing

Scaffold a backend entity **grid/listing** the modern way — a declarative
`view/adminhtml/ui_component/{entity}_listing.xml` bound to a `DataProvider`, with an actions
column, mass-action controllers, and an `Index` controller — optionally wired to a sibling edit
form. Never the legacy `Magento\Backend\Block\Widget\Grid`.

## Core Rules

- **Declarative UI component only.** The listing is XML (`ui_component/{entity}_listing.xml`) + a
  PHP `DataProvider`. Never generate `Block\Widget\Grid` / `Block\Widget\Grid\Container`.
- **The naming contract prevents the empty grid.** These five names MUST agree, or the grid
  renders empty with no error:
  1. file name → `{vendor_lower}_{module_lower}_{entity}_listing.xml`
  2. `js_config` → `provider` → `{LISTING}.{SOURCE}` where `LISTING={vendor_lower}_{module_lower}_{entity}_listing` and `SOURCE={LISTING}_data_source`
  3. `<settings>` → `<deps>` → `<dep>` → `{LISTING}.{SOURCE}`
  4. `<dataSource name>` and inner `<dataProvider name>` → both `{SOURCE}`
  5. `<columns name>` → `{vendor_lower}_{module_lower}_{entity}_columns` (referenced by `<spinner>`)
- **Default DataProvider is `AbstractDataProvider` + `CollectionFactory`.** `AbstractDataProvider::getData()` already returns the grid shape (`['items' => [...], 'totalRecords' => N]`) — do NOT override `getData()`. Inject `CollectionFactory` and assign `$this->collection`. See `references/dataprovider-wiring.md`.
- **Optional SearchResult path.** For joins or large grids, swap the PHP DataProvider for the generic `Magento\Framework\View\Element\UiComponent\DataProvider\DataProvider` plus a `di.xml` `CollectionFactory.collections` map pointing to `Grid\Collection extends SearchResult`. The `di-listing.xml` template handles this. See `references/dataprovider-wiring.md` and `references/grid-collection.md`.
- **`selectionsColumn` is required for mass actions.** Without `<selectionsColumn name="ids">`, the mass-action checkboxes never appear and mass actions are silently inert.
- **`actionsColumn` must carry the correct `indexField`.** The `indexField` setting in `<actionsColumn>` must match the primary key column (e.g. `faq_id` for `faq`). A mismatch produces blank or broken edit/delete URLs.
- **Reuse the form's acl/menu/routes when present.** If `magento2-adminhtml-form` already created `etc/adminhtml/routes.xml`, `etc/acl.xml`, and `etc/adminhtml/menu.xml` for the same module, do not overwrite them — merge only the listing's ACL resource if absent. Create them when the listing is standalone. **When reusing, the listing's own generated artifacts must reference the FORM's route-id (`{vendor_lower}_{entity}`) and ACL resource (`{Vendor}_{ModuleName}::{entity}`)** — in the `Index`/mass-action controllers' `ADMIN_RESOURCE`, the `<aclResource>` in `{entity}_listing.xml`, the layout handle, the menu `action`/`resource`, and the actions-column Edit/Delete/Add-New URLs — **not** this skill's standalone `{vendor_lower}_{module_lower}` / `::main` defaults, which would not match what the form created (an admin route-404 / access-denied on Edit and Delete). The two skills must resolve to one route-id and one base ACL resource for the same module.
- **Layout uses `admin-1column`.** The listing layout (`layout-index.xml`) must declare `layout="admin-1column"` — a full-width grid. `admin-2columns-left` leaves an empty left column.
- **Never assume a running Magento instance.** Generate files; do not call `bin/magento` or hit the database during generation. `setup:upgrade` is a post-gen command listed in the Phase 5 report.
- **Edition awareness.** Detect `{ctx.edition}`. A basic grid is Open Source-compatible. Flag Commerce-only features (e.g. advanced column types, staging) and gate them. See `references/edition-differences.md`.
- **Test-first.** Write the failing test before the listing code (red → green) and watch it fail for the right reason. See `magento2-context/references/tdd-discipline.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 baseline, Magento 2 standard taking precedence; `--standard=Magento2` PHPCS is the gate. See `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx}`. Abort with a clear message if the target module does
not exist (offer `magento2-module-create`) or if `{ctx.magento_root}` is unresolved.

### Phase 1 — Resolve Inputs

Ask for any missing values:

| Input | Default | Notes |
|-------|---------|-------|
| Target module | (ask) | Existing `{Vendor}_{Module}`; offer `magento2-module-create` if absent |
| Entity name | (ask) | PascalCase `{EntityName}` + lowercase `{entity}` (e.g. `Faq`/`faq`) |
| Primary key column | `{entity}_id` | The id column referenced by `selectionsColumn` and `actionsColumn`; matches the paired form's `getParam('{entity}_id')` |
| Columns | (ask) | Each: name, label, column type, filter type, sortOrder |
| Has status field? | (ask) | Enables MassStatus controller + enable/disable mass actions |
| Paired form? | (ask) | Name of the edit form (used for actions column routes); "none" if standalone |
| Performance path? | No | Use `SearchResult` + `di` map when joins / large tables are needed |
| ACL resource | `{Vendor}_{Module}::main` | Guards Index + mass controllers |

Consult `references/columns-and-types.md`, `references/edition-differences.md` while asking.

### Phase 2 — Plan

Present the file plan (every path to create/modify, surfaces enabled, ACL/route/menu touches,
DataProvider wiring chosen). Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing test (RED).** Before any listing code, add a test under `Test/Integration/`
that boots the `DataProvider` and asserts `getData()` returns the grid shape
(`['items' => [...], 'totalRecords' => N]`), plus a controller test (Index returns HTTP 200 and
the correct page title; MassDelete processes the correct collection). If no test DB is available,
fall back to a unit test of the DataProvider construction and **record the gap** in the Phase 5
report. Run it and confirm it fails for the right reason. See
`magento2-context/references/tdd-discipline.md`.

**3B — Generate (GREEN).** Write the minimal files from `templates/` to turn 3A green:

- `templates/listing.xml` → `view/adminhtml/ui_component/{vendor_lower}_{module_lower}_{entity}_listing.xml`
- `templates/data-provider.php` → `Ui/DataProvider/{EntityName}DataProvider.php`
- `templates/column-actions.php` → `Ui/Component/Listing/Column/{EntityName}Actions.php`
- `templates/controller-index.php` → `Controller/Adminhtml/{EntityName}/Index.php`
- `templates/controller-mass-delete.php` → `Controller/Adminhtml/{EntityName}/MassDelete.php`
- `templates/controller-mass-status.php` → `Controller/Adminhtml/{EntityName}/MassStatus.php` (when status surface enabled)
- `templates/layout-index.xml` → `view/adminhtml/layout/{vendor_lower}_{module_lower}_{entity}_index.xml`
- `templates/routes.xml`, `acl.xml`, `menu.xml` (created-if-absent / merged-from-form)
- Optional: `templates/di-listing.xml` + `templates/grid-collection.php` (SearchResult path)

### Phase 4 — Verify

- `xmllint --noout` on every XML (`{ctx.tools.xmllint}`): listing, layout, routes, acl, menu, di.
- `php -l` on every PHP file.
- Run the Phase 3A test with `{ctx.runner} vendor/bin/phpunit`; confirm it now **passes**; run the module suite to confirm no regressions.
- Confirm the five naming-contract names agree (the empty-grid check).
- **Apply the shared module-hygiene baseline (required).** After generating or modifying PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files that already
  carry it). If you add a `composer.json` `require` entry, resolve a **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.
- Optionally run `magento2-module-review` on the module → zero Critical/High.
- `scripts/verify-listing.sh` runs the XML + PHP lints in one pass.

### Phase 5 — Report

Brief Markdown saved to `.docs/adminhtml-listings/{Vendor}_{Module}-{entity}-listing-{date}.md`:

- Files generated/modified + surfaces enabled
- Test path + red→green evidence (or recorded gap)
- Post-gen commands: `bin/magento setup:upgrade` (if di/routes/menu/acl changed), cache flush, `setup:di:compile` note for production
- The listing's admin URL + ACL resource to grant
- Links to `magento2-module-review` and `magento2-test-generate`

## Inputs

```
/magento2-adminhtml-listing --module=Acme_Faq --entity=Faq --primary=faq_id --status --paired-form=acme_faq_faq
```

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/view/adminhtml/ui_component/{vendor_lower}_{module_lower}_{entity}_listing.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/Ui/DataProvider/{EntityName}DataProvider.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Ui/Component/Listing/Column/{EntityName}Actions.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Controller/Adminhtml/{EntityName}/Index.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Controller/Adminhtml/{EntityName}/MassDelete.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Controller/Adminhtml/{EntityName}/MassStatus.php  # status surface
{ctx.magento_root}/app/code/{Vendor}/{Module}/view/adminhtml/layout/{vendor_lower}_{module_lower}_{entity}_index.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/adminhtml/{routes,menu}.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/acl.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/di.xml                             # optional: SearchResult path
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/ResourceModel/{EntityName}/Grid/Collection.php  # optional
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration/.../{EntityName}ListingTest.php    # test-first

.docs/adminhtml-listings/{Vendor}_{Module}-{entity}-listing-{date}.md
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under `{ctx.magento_root}`.
See the **Artifact location** rule in `magento2-context/SKILL.md`.

## Reference Files

- `references/listing-xml-anatomy.md` — `{entity}_listing.xml` structure + the 5-place naming contract.
- `references/dataprovider-wiring.md` — default `AbstractDataProvider` path vs optional `SearchResult`+di path.
- `references/columns-and-types.md` — text/select/date/actionsColumn, filters, options sources, sortOrder.
- `references/mass-actions.md` — selectionsColumn + massaction + MassDelete/MassStatus controllers + Filter pattern.
- `references/grid-collection.md` — SearchResult collection (joins, mainTable/resourceModel, `_initSelect`).
- `references/controllers-and-routing.md` — Index + mass controllers, ADMIN_RESOURCE, routes, layout handles.
- `references/edition-differences.md` — Open Source vs Adobe Commerce grid notes.
- `references/pairing-with-form.md` — actions column / Add-New button targeting the form's routes; reusing acl/menu/routes; `admin-1column` layout.
- `references/pitfalls.md` — empty grid, inert mass actions, broken actionsColumn, wrong layout handle.
- `magento2-context/references/tdd-discipline.md` — shared test-first loop (Phase 3A).

## Templates

- `templates/listing.xml`
- `templates/data-provider.php`
- `templates/column-actions.php`
- `templates/controller-index.php`
- `templates/controller-mass-delete.php`
- `templates/controller-mass-status.php`
- `templates/layout-index.xml`
- `templates/routes.xml`, `templates/acl.xml`, `templates/menu.xml`
- `templates/di-listing.xml` (optional: SearchResult path)
- `templates/grid-collection.php` (optional: SearchResult path)

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md` using the `{Vendor}` / `{ModuleName}` /
`{EntityName}` / `{entity}` / `{vendor_lower}` / `{module_lower}` convention. Every token used
must be registered there — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- The five naming-contract names agree; the grid loads rows and paginates.
- `selectionsColumn` present and `actionsColumn` carries the correct `indexField`.
- DataProvider returns the grid shape without overriding `getData()`.
- `acl.xml` has no `translate` attribute; every XML passes `xmllint --noout`.
- A test asserting DataProvider construction + grid shape **and** the Index controller render was written and **watched to fail** before the listing existed, and passes after (or the gap is recorded).
- No Commerce-only wiring emitted on Open Source.
- Passes `magento2-module-review` with zero Critical/High findings.

## Common Pitfalls Handled

| Pitfall | How the skill avoids it |
|---------|--------------------------|
| Empty grid | The five-name naming contract is generated consistently |
| Mass actions inert | `selectionsColumn` always generated before any `<massaction>` element |
| Broken edit/delete URLs | `actionsColumn indexField` matches the primary key column |
| Wrong layout (empty left column) | `admin-1column` declared in `layout-index.xml` |
| DataProvider returns wrong shape | `AbstractDataProvider::getData()` not overridden — grid shape by default |
| `xmllint` fails on acl.xml | No `translate` attribute on `<resource>` |
| Empty grid on SearchResult path | `di.xml` collections map key matches `{SOURCE}` name byte-for-byte |
| Commerce-only features on Open Source | Edition checked in Phase 1; advanced features gated |
| Legacy `Block\Widget\Grid` | Skill refuses; declarative UI component only |

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| upstream | `magento2-module-create` — create the module first if absent; defers here for standalone grids |
| sibling | `magento2-adminhtml-form` — the edit form this listing's actions column links to |
| downstream | `magento2-test-generate` — fuller unit/integration/MFTF coverage |
| gate | `magento2-module-review` — acceptance gate (zero Critical/High) |
| (caller) | `magento2-feature-implement` — the admin-listing slice of a feature |
