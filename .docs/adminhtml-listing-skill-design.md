# Design: `magento2-adminhtml-listing` skill

**Status:** Approved design (2026-06-17) — pending spec review, then implementation plan.
**Scope:** the `magento2-tools` plugin. Adds the 19th skill — an adminhtml UI-component **grid/listing** generator — mirroring `magento2-adminhtml-form`. Plus registration (versioning, README count 18→19, docs, CHANGELOG).
**Author:** drafted via Claude Code for the magento2-tools plugin.

---

## 1. Why

`magento2-adminhtml-form` owns the admin **edit-form** surface end-to-end; nothing owns the admin **grid/listing** surface. `magento2-module-create` emits only a basic listing stub. The declarative `ui_component/{entity}_listing.xml` + its DataProvider `di.xml` wiring is the second most boilerplate-heavy, error-prone admin surface — the canonical failure is an **empty grid** because the `CollectionFactory.collections[]` map / `SearchResult` virtual-type collection is mis-wired. This skill makes that correct by construction, exactly as the form skill did for "blank form / silent save".

## 2. Decisions (locked)

- **Scope: Core + common surfaces** — toolbar (bookmark, columnsControls, filterSearch, filters, massaction, paging), DataProvider di-wiring, columns incl. an **actions column** (edit/delete) and a **selectionsColumn**, **mass actions** (delete + enable/disable), the Index controller + listing layout, a `SearchResult` grid collection, and acl/menu/routes. (No inline-editing or export in v1.)
- **Mirror `magento2-adminhtml-form`**: same phased workflow, edition gating, test-first generate→verify, and the "passes `magento2-module-review` with zero Critical/High" guarantee.
- **Pairs with `adminhtml-form`**: the actions column + mass-delete target an existing edit form's routes when present; acl/menu/routes are **reused** if the form already created them, else created. Standalone when no form exists.
- **Wiring (revised after reading the code):** default = `AbstractDataProvider` + `CollectionFactory` (consistent with `module-create`'s existing stub; fewer pitfalls). **Baked-in correctness = the listing naming contract** — the `{vendor_lower}_{module_lower}_{entity}_listing` / `…_listing_data_source` names agreeing across all **5 places** in `listing.xml` (js_config `provider`, `deps` dep, `dataSource name`, inner `dataProvider name`, `columns` spinner). That's the real empty-grid pitfall here and the analog of the form skill's five-name contract. The `SearchResult` `Grid\Collection` + `di` `CollectionFactory.collections` map is an **optional** performance/joins surface, not the default.
- **No behaviour change to other skills** beyond the documented `module-create` deferral note + the README/registry updates.

## 3. The listing naming contract (the load-bearing pattern)

**Default wiring** — `{Entity}DataProvider extends AbstractDataProvider` (CollectionFactory injected; `getData()` not overridden — `AbstractDataProvider` already returns the grid shape), referenced directly in `listing.xml`. The empty-grid pitfall is a **name mismatch**: the data-source name must be byte-identical in all 5 spots:

```
LISTING = {vendor_lower}_{module_lower}_{entity}_listing
SOURCE  = {LISTING}_data_source
listing.xml:
  js_config provider  = {LISTING}.{SOURCE}
  deps/dep            = {LISTING}.{SOURCE}
  dataSource name     = {SOURCE}
  dataProvider name   = {SOURCE}   (class = {Vendor}\{ModuleName}\Ui\DataProvider\{EntityName}DataProvider)
  columns spinner     = {vendor_lower}_{module_lower}_{entity}_columns
```

The skill (and `verify-listing.sh`) enforce this agreement — the analog of the form skill's five-name contract.

**Optional performance wiring** — for joins/large grids, swap the PHP DataProvider for the generic `Magento\Framework\View\Element\UiComponent\DataProvider\DataProvider` + a `di.xml` map:
```
<type CollectionFactory> collections[ "{SOURCE}" ] = …\Model\ResourceModel\{Entity}\Grid\Collection
<virtualType …\Grid\Collection type=SearchResult> mainTable, resourceModel
```
This path has its own (di-map) name-agreement requirement, also enforced when chosen.

## 4. Components

**New skill `skills/magento2-adminhtml-listing/`:**

- `SKILL.md` — Core Rules + phased Workflow (Phase 0 Context → 1 Resolve Inputs → 2 Plan → 3 Test First, then Generate → 4 Verify → 5 Report) + Inputs/Outputs/References/Templates/Acceptance/Pitfalls/Related, mirroring `adminhtml-form/SKILL.md`.

- **templates/ (~14):**
  - `listing.xml` — `ui_component/{entity}_listing.xml` (dataSource referencing the PHP DataProvider, listingToolbar, Add-New button, selectionsColumn, id + sample columns, actionsColumn) — the 5-place naming contract.
  - `data-provider.php` — **default** `Ui/DataProvider/{EntityName}DataProvider.php` (`extends AbstractDataProvider`, CollectionFactory injected; `getData()` not overridden), mirroring `module-create`'s `admin-ui-data-provider.php`.
  - `di-listing.xml` — **optional** (performance path): `CollectionFactory.collections` map + `Grid\Collection` SearchResult virtualType + aclResource.
  - `grid-collection.php` — **optional** (performance path): `Model/ResourceModel/{Entity}/Grid/Collection.php` SearchResult subclass.
  - `column-actions.php` — `Ui/Component/Listing/Column/Actions.php` (edit/delete links → form routes).
  - `controller-index.php` — `Controller/Adminhtml/{Entity}/Index.php` (renders the listing page).
  - `controller-mass-delete.php` — `Controller/Adminhtml/{Entity}/MassDelete.php`.
  - `controller-mass-toggle.php` — `MassEnable`/`MassDisable` (status toggle).
  - `layout-index.xml` — `{route}_{controller}_index.xml` adding the `{entity}_listing` uiComponent.
  - `acl.xml`, `menu.xml`, `routes.xml` — created-if-absent / reused-from-form.
  - (small button/helpers as needed, e.g. an Add-New button block if not inlined in listing.xml.)

- **references/ (~9):** `listing-xml-anatomy.md`, `dataprovider-di-wiring.md` (load-bearing), `columns-and-types.md`, `mass-actions.md`, `grid-collection.md`, `controllers-and-routing.md`, `edition-differences.md`, `pairing-with-form.md`, `pitfalls.md`.

- **scripts/`verify-listing.sh`** — `php -l` + `xmllint` over generated templates (mirrors `verify-form.sh`).

**Registration / footprint (outside the skill dir):**
- `skills/magento2-context/references/skill-versioning.md` — add `magento2-adminhtml-listing 1.0.0` row + changelog note.
- `README.md` — skills table (+ row), the **count 18 → 19** (table intro, Layout comment, dependency graph), dependency-graph edges.
- `docs/skills-reference.md` — a per-skill entry + a row in the "Choosing between adjacent skills" table (if that PR has merged; otherwise additive).
- `docs/README.md` and any other "N skills" prose → 19 (the `test-skill-count-consistency` guard enforces this).
- `CHANGELOG.md` `[Unreleased]`.

## 5. Test / verification strategy

- **Repo contract tests must stay green**: every new template passes `test-template-php-lint` (`php -l`), `test-template-xml-lint` (`xmllint`), placeholder-token checks, reference-integrity (`${CLAUDE_SKILL_DIR}` / cross-refs), `test-skill-frontmatter`, and `test-skill-count-consistency` (now 19). `test-version-registry-consistency` must include the new skill.
- **Test-first build** (mirrors adminhtml-form): a RED baseline capturing unaided grid failure modes (empty-grid di mismatch, missing selectionsColumn for mass actions, actions column wrong index field), templates written to eliminate exactly those, GREEN via the repo template-lint harness.
- The skill's own templates use the repo placeholder tokens (`{{VENDOR}}`, `{{MODULE}}`, etc. per `placeholder-schema.md`) so the placeholder-token test passes.

## 6. Non-goals

- No inline editing, no export, no advanced filter/column types in v1 (future increment).
- No changes to `adminhtml-form` or other skills' behaviour (only the README registry + a one-line `module-create` deferral note if cheap).
- Not a runtime tool — generates files; never assumes a running Magento instance (same as the form skill).

## 7. Implementation-time verification

- Read `magento2-adminhtml-form`'s SKILL.md + templates + `placeholder-schema.md` + the existing `module-create` listing stub templates, and follow them verbatim as the pattern (naming, placeholder tokens, header/license style, di structure).
- After generation: run the full `tests/run-all.sh`; the new templates must pass every template-lint + the count guard at 19 + version-registry consistency.

## 8. Versioning & docs

- New skill `1.0.0`; plugin minor bump applies at next release (not part of this change — handled by the release flow). CHANGELOG `[Unreleased]` entry. README/docs counts to 19.
