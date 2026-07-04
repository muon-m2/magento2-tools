---
name: magento2-adminhtml-form
description:
    Generate a Magento 2 adminhtml UI-component edit form — the modern declarative
    ui_component/{entity}_form.xml plus its DataProvider, button blocks, and the
    New/Edit/Save/Delete controllers wired to a listing. Use when the user wants to add or
    scaffold a new admin form, an entity edit page, a "New/Edit" backend screen, fieldsets,
    a WYSIWYG field, a toggle, dynamic-rows, or file/image uploaders in the Magento admin.
    Detects edition (Open Source vs Adobe Commerce) and flags Commerce-only form features.
    Produces files that pass magento2-module-review with zero Critical/High findings.
---

# Magento 2 Adminhtml Form

Scaffold a backend entity **edit form** the modern way — a declarative
`view/adminhtml/ui_component/{entity}_form.xml` bound to a `DataProvider`, with button
blocks and `New`/`Edit`/`Save`/`Delete` controllers — wired to an existing listing grid.
Never the legacy `Magento\Backend\Block\Widget\Form`.

## Core Rules

- **Declarative UI component only.** The form is XML (`ui_component/{entity}_form.xml`) + a
  PHP `DataProvider`. Never generate `Block\Widget\Form` / `Block\Widget\Form\Container`.
- **The naming contract prevents the blank form.** These five names MUST agree, or the form
  renders empty with no error:
  1. form `<namespace>` and file name → `{entity}_form`
  2. `provider` in `js_config` → `{entity}_form.{entity}_form_data_source`
  3. `<dataSource name>` and `<dataProvider name>` → `{entity}_form_data_source`
  4. layout `<uiComponent name>` → `{entity}_form`
  5. layout handle file → `<route_id>_<controller>_edit.xml` (route id + controller path + action)
- **Button blocks are required.** The `<buttons>` in the form reference PHP block classes; the
  page errors if they are missing. Always emit `GenericButton` + `Back`, `Save`, `Delete`
  (and `SaveAndContinue` when save-and-continue is requested).
- **DataProvider shape is exact.** Extend `Magento\Ui\DataProvider\AbstractDataProvider`
  (modifier-less default) or `Magento\Ui\DataProvider\ModifierPoolDataProvider` (only when
  modifiers are requested). `getData()` returns `[ $id => [field => value, …] ]` — flat fields,
  keyed by entity id. Inject `DataPersistorInterface` so a failed save (and the New screen)
  repopulates. See `references/dataprovider-patterns.md`.
- **Save reads FLAT post data.** A standard UI form posts fields flat;
  `$this->getRequest()->getPostValue()` → `[{entity}_id, …fields]`. Do **not** unwrap a
  `data`/`general` key. Normalise empty id to `null` before `repository->save()`.
- **The modifier/Pool is an OPTIONAL surface.** Default to modifier-less for a new simple form.
  Generate a `Modifier` + `di-modifier-pool.xml` only when extending an existing form
  (product/customer) or building fields dynamically. See `references/modifier-patterns.md`.
- **acl.xml has no `translate` attribute.** `acl.xsd` allows only `id`, `title`, `sortOrder`,
  `disabled` on `<resource>`. `menu.xml` *does* allow `translate`. Mixing them fails xmllint.
- **No storefront handles.** The edit layout is just `<referenceContainer name="content"><uiComponent .../></referenceContainer>`. Do not add `<update handle="styles"/>` (storefront-only).
- **Edition awareness.** Detect `{ctx.edition}`. Content-staging tabs and B2B company forms are
  **Adobe Commerce only** — never emit staging wiring on Open Source. See
  `references/edition-differences.md`.
- **Test-first.** Write the failing test before the form code (red → green) and **watch it fail
  for the right reason**. See `magento2-context/references/tdd-discipline.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 baseline, Magento 2 standard taking
  precedence; `--standard=Magento2` PHPCS is the gate. See
  `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx}`. Abort with a clear message if the target module
does not exist (offer `magento2-module-create`) or if `{ctx.magento_root}` is unresolved.

### Phase 1 — Resolve Inputs

Ask for any missing values:

| Input | Default | Notes |
|-------|---------|-------|
| Target module | (ask) | Existing `{Vendor}_{Module}`; offer `magento2-module-create` if absent |
| Entity name | (ask) | PascalCase `{Entity}` + lowercase `{entity}` (e.g. `Faq`/`faq`) |
| Data loading | (ask) | Existing repository/collection for the entity (must exist) |
| Primary field | `{entity}_id` | The id column / request param / redirect key |
| Fields | (ask) | Each: code, label, `formElement`, `dataType`, required?, source options |
| Surfaces | (ask) | modifier? wysiwyg? toggle? dynamicRows? uploader? dependent fields? delete? save-and-continue? menu entry? |
| Listing to return to | (ask) | Name of the grid the Back button / save redirect target (or "none yet") |
| ACL resource | `{Vendor}_{Module}::{entity}` | Guards Save/Delete controllers |

Consult `references/field-types.md`, `references/validation-rules.md`,
`references/edition-differences.md` while asking so offered options match `{ctx.edition}`.

### Phase 2 — Plan

Present the file plan (every path to create/modify, surfaces enabled, ACL/route/menu touches).
Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing test (RED).** Before any form code, add a test under `Test/Integration/`
that boots the `DataProvider` and asserts `getData()` returns the entity shaped as
`[$id => [...]]`, plus a controller test (Save redirects + sets a success message; Edit 404s/
redirects for a missing id, renders for an existing one). If no test DB is available, fall back to
a unit test of any `Modifier::modifyMeta`/`modifyData` and **record the gap** in the Phase 5
report. Run it and confirm it fails for the right reason. See
`magento2-context/references/tdd-discipline.md` and
`magento2-test-generate/references/integration-patterns.md`.

**3B — Generate (GREEN).** Write the minimal files from `templates/` to turn 3A green:

- `templates/form.xml` → `view/adminhtml/ui_component/{entity}_form.xml`
- `templates/data-provider.php` → `Model/{Entity}/DataProvider.php`
- `templates/controller-new.php`, `controller-edit.php`, `controller-save.php`, `controller-delete.php`
- `templates/generic-button.php` + `back-button.php`, `save-button.php`, `delete-button.php`
  (+ `save-and-continue-button.php` when requested)
- `templates/routes.xml`, `acl.xml`, `menu.xml` (as needed), `layout-edit.xml`
- Optional: `templates/modifier.php` + `di-modifier-pool.xml` (modifier surface)

### Phase 4 — Verify

- `xmllint --noout` on every XML (`{ctx.tools.xmllint}`): form, layout, routes, acl, menu, di.
- `php -l` on every PHP file.
- Run the Phase 3A test with `{ctx.runner} vendor/bin/phpunit`; confirm it now **passes**; run
  the module suite to confirm no regressions.
- Confirm the five naming-contract names agree (the blank-form check).
- **Apply the shared module-hygiene baseline (required).** After generating or modifying PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files that already
  carry it). If you add a `composer.json` `require` entry, resolve a **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.
- Optionally run `magento2-module-review` on the module → zero Critical/High.
- `scripts/verify-form.sh` runs the XML + PHP lints in one pass.

### Phase 5 — Report

Brief Markdown saved to `{output_root}/adminhtml-forms/{Vendor}_{Module}-{entity}-form-{date}.md`:

- Files generated/modified + surfaces enabled
- Test path + red→green evidence (or recorded gap)
- Post-gen commands: `bin/magento setup:upgrade` (if di/routes/menu/acl changed), cache flush,
  `setup:di:compile` note for production
- The form's admin URL + ACL resource to grant
- Links to `magento2-module-review` and `magento2-test-generate`

## Inputs

```
/magento2-adminhtml-form --module=Acme_Faq --entity=Faq --primary=faq_id --wysiwyg=content --listing=acme_faq_listing [--docs-root=<path>]
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/view/adminhtml/ui_component/{entity}_form.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/{Entity}/DataProvider.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Controller/Adminhtml/{Entity}/{New,Edit,Save,Delete}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/*Button.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/view/adminhtml/layout/{vendor_lower}_{entity}_{entity}_edit.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/adminhtml/{routes,menu,di}.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/acl.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration/.../{Entity}FormTest.php   # test-first (Phase 3A)

{output_root}/adminhtml-forms/{Vendor}_{Module}-{entity}-form-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`. See the **Artifact location** rule in `magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/adminhtml-forms/`; otherwise default to
`{ctx.docs_root}/adminhtml-forms/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `references/form-xml-anatomy.md` — `{entity}_form.xml` structure + the naming contract.
- `references/dataprovider-patterns.md` — DataProvider base classes, `getData()` shape, persistor.
- `references/modifier-patterns.md` — `ModifierInterface` + Pool (optional surface).
- `references/field-types.md` — `formElement`/`dataType` map; toggle, dynamicRows.
- `references/validation-rules.md` — `required-entry`, `validate-number`, custom + server-side.
- `references/dependent-fields.md` — show/hide via `imports`/`exports`, `switcherConfig`.
- `references/controllers-and-routing.md` — controllers, ACL, routes, layout handle derivation.
- `references/uploaders-wysiwyg.md` — image/file uploader controller + WYSIWYG wiring.
- `references/edition-differences.md` — Open Source vs Adobe Commerce (staging, B2B).
- `references/pitfalls.md` — blank-form / silent-save / 404 root causes and fixes.
- `magento2-context/references/tdd-discipline.md` — shared test-first loop (Phase 3A).

## Templates

- `templates/form.xml`
- `templates/data-provider.php`
- `templates/controller-new.php`, `controller-edit.php`, `controller-save.php`, `controller-delete.php`
- `templates/generic-button.php`, `back-button.php`, `save-button.php`, `delete-button.php`,
  `save-and-continue-button.php`
- `templates/routes.xml`, `acl.xml`, `menu.xml`, `layout-edit.xml`
- `templates/modifier.php`, `di-modifier-pool.xml` (modifier surface)

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md` using the `{Vendor}` / `{Module}` /
`{Entity}` / `{entity}` convention. Every token used must be registered there —
`tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- The five naming-contract names agree; the form loads existing data and saves it.
- Button block classes exist for every `<button>` referenced by the form.
- DataProvider returns `[$id => [...]]` and injects `DataPersistorInterface`.
- `acl.xml` has no `translate` attribute; every XML passes `xmllint --noout`.
- A test asserting `getData()` shape **and** the Save/Edit controller behaviour was written and
  **watched to fail** before the form existed, and passes after (or the gap is recorded).
- No Commerce-only wiring emitted on Open Source.
- Passes `magento2-module-review` with zero Critical/High findings.

## Common Pitfalls Handled

| Pitfall | How the skill avoids it |
|---------|--------------------------|
| Blank form on Edit | The five-name naming contract is generated consistently |
| Save writes empty/garbage rows | Flat `getPostValue()`; empty id normalised to `null` |
| Form errors on load | Button block classes always generated for referenced buttons |
| New-record / failed-save loses input | `DataPersistorInterface` injected into the DataProvider |
| `xmllint` fails on acl.xml | No `translate` attribute on `<resource>` |
| Blank content area | Layout handle derived as `<route_id>_<controller>_edit` |
| WYSIWYG renders as plain textarea | Canonical `formElement="wysiwyg"` + `wysiwygConfigData` |
| Commerce-only features on Open Source | Edition checked in Phase 1; staging/B2B gated |
| Legacy `Block\Widget\Form` | Skill refuses; declarative UI component only |

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| upstream | `magento2-module-create` — create the module first if absent |
| sibling | `magento2-eav-attribute` — add an attribute, then expose it on this form |
| downstream | `magento2-test-generate` — fuller unit/integration/MFTF coverage |
| gate | `magento2-module-review` — acceptance gate (zero Critical/High) |
| (caller) | `magento2-feature-implement` — the admin-form slice of a feature |
