---
name: magento2-system-config
description:
    Add admin store configuration to an existing module — system.xml section/group/field,
    config.xml defaults, ACL, optional source/backend models, plus a typed Config reader
    (ScopeConfigInterface wrapper with store-aware getters). Use for 'add a config
    field/toggle/API-key setting' in Stores → Configuration. For an admin **data** edit
    form use `magento2-adminhtml-form`; for a new module use `magento2-module-create`.
---

# Magento 2 System Config

Add admin Stores → Configuration settings to an existing Magento 2 module: `system.xml`
section/group/field declarations, `config.xml` defaults, `acl.xml` resource, optional
source and backend models, and a typed `Config` reader that wraps `ScopeConfigInterface`.

## Core Rules

- **Config path convention:** `{vendor_lower}_{module_lower}/{GroupId}/{FieldId}` (all
  lowercase). The section id is the first segment only when it differs from
  `{vendor_lower}_{module_lower}`; typically one module owns one section. See
  `magento2-context/references/naming.md`.
- **Secrets use the Encrypted backend model.** Any API key or password field must declare
  `backend_model="Magento\Config\Model\Config\Backend\Encrypted"` and `type="obscure"` in
  `system.xml`. The typed reader decrypts via `encryptor->decrypt()` before returning.
- **Never read config ad-hoc in business code.** All `ScopeConfigInterface::getValue()`
  calls must go through the generated typed reader. Business classes receive the reader
  via DI; they never import `ScopeConfigInterface` directly.
- **ACL.** The config resource node nests under `{Vendor}_{Module}::config` (a child of
  `{Vendor}_{Module}::main`, under `Magento_Config::config` conceptually in the ACL tree).
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
JSON as `{ctx}`. Abort if `{ctx.magento_root}` is unresolved. If the target module does
not exist, stop and offer `magento2-module-create` first — do not scaffold config into a
non-existent module.

### Phase 1 — Resolve Inputs

Ask for any missing values in one batch:

| Input | Default | Notes |
|-------|---------|-------|
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Section id | `{vendor_lower}_{module_lower}` | snake_case, appears in Stores → Config sidebar |
| Section label | (ask) | Human-readable, e.g. `"Acme Checkout"` |
| Section tab | `general` | Tab id in Stores → Config, e.g. `general`, `catalog`, `sales` |
| Group(s) | (ask) | One or more group ids (snake_case) + labels |
| Fields per group | (ask) | Per field: id, label, type, sortOrder, showInDefault, showInWebsite, showInStore, source\_model?, backend\_model?, comment?, depends? |
| Generate typed reader? | yes | Creates `Model/Config.php` + `Test/Unit/Model/ConfigTest.php` |

See `${CLAUDE_SKILL_DIR}/references/field-types.md`,
`${CLAUDE_SKILL_DIR}/references/scope-and-paths.md`,
`${CLAUDE_SKILL_DIR}/references/system-xml-anatomy.md`.

### Phase 2 — Plan

Present every file to create or modify. Typical file set:

- `etc/adminhtml/system.xml` (merge) — section/group/field tree
- `etc/config.xml` (merge) — `<default>` values
- `etc/acl.xml` (merge) — config ACL resource
- `Model/Config/Source/{SourceName}.php` — for each select/multiselect field (optional)
- `Model/Config/Backend/{BackendModelName}.php` — for each custom backend model (optional)
- `Model/Config.php` — typed reader (when requested)
- `Test/Unit/Model/ConfigTest.php` — unit test for the typed reader
- `Test/Unit/Model/Config/Source/{SourceName}Test.php` — unit test per source model

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing tests (RED).** Before generating implementation code, write
tests that express expected behaviour and confirm they fail for the right reason:

- **Typed reader test** (`Test/Unit/Model/ConfigTest.php`): mock
  `Magento\Framework\App\Config\ScopeConfigInterface` and
  `Magento\Store\Model\ScopeInterface`; for each getter assert that `getValue` (or
  `isSetFlag` for boolean/toggle fields) is called with the exact config path
  `{vendor_lower}_{module_lower}/{GroupId}/{FieldId}` and the correct scope constant,
  and that the return value is cast to the declared type. Use real
  `self::assertSame(...)` and `expects(self::once())` mock expectations — no
  `markTestIncomplete`, no `self::assertTrue(true)`.
- **Source model test** (per source model): assert that `toOptionArray()` returns an
  array whose entries each have `value` and `label` keys.

Follow `magento2-context/references/tdd-discipline.md`. Run tests and confirm they fail
for the right reason.

**3B — Generate implementation (GREEN).** Write the minimal code to make the 3A tests
pass, using the templates:

- `${CLAUDE_SKILL_DIR}/templates/system.xml`
- `${CLAUDE_SKILL_DIR}/templates/config.xml`
- `${CLAUDE_SKILL_DIR}/templates/acl.xml`
- `${CLAUDE_SKILL_DIR}/templates/source-model.php`
- `${CLAUDE_SKILL_DIR}/templates/backend-model.php`
- `${CLAUDE_SKILL_DIR}/templates/config-reader.php`
- `${CLAUDE_SKILL_DIR}/templates/test-config-reader-unit.php`
- `${CLAUDE_SKILL_DIR}/templates/test-source-model-unit.php`

See `${CLAUDE_SKILL_DIR}/references/config-reader-pattern.md` and
`${CLAUDE_SKILL_DIR}/references/encrypted-fields.md`.

### Phase 4 — Verify

- `php -l` on every generated `.php` file.
- `xmllint --noout` on every generated `.xml` file.
- Run the Phase 3A tests with `{ctx.runner} vendor/bin/phpunit` and confirm they now
  **pass** (they failed before 3B).
- **Apply the shared module-hygiene baseline (required).** After generating or modifying
  PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips
  files that already carry it). If you add a `composer.json` `require` entry, resolve a
  **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.
- Run `magento2-module-review --diff` (gate: zero Critical/High findings).
- Check that admin path `Stores → Configuration → {SectionLabel}` shows the group and
  fields (manual or via `bin/magento config:show` in a running instance).

### Phase 5 — Report

Write a brief Markdown report to
`{output_root}/system-config/{Vendor}_{Module}-{SectionId}-{date}.md` listing:

- Admin path: `Stores → Configuration → {SectionLabel}`
- Config paths (one per field: `{vendor_lower}_{module_lower}/{GroupId}/{FieldId}`)
- ACL resource: `{Vendor}_{Module}::config`
- Default values (from `config.xml`)
- Files generated
- Test path + red→green evidence
- `bin/magento setup:upgrade` + `bin/magento cache:flush` commands

> **Docs may now be stale.** This change modified module code. Run
> `magento2-docs-generate --module={Vendor}_{Module}` to refresh the module's README,
> CHANGELOG, and `docs/*.md` (technical reference, guides, and API references as
> applicable).

## Inputs

```
/magento2-system-config --module=Acme_Checkout --section=acme_checkout --group=general --field=enable_feature --type=select
/magento2-system-config --module=Acme_Catalog --section=acme_catalog --group=api --field=api_key --type=obscure [--docs-root=<path>]
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/adminhtml/system.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/config.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/acl.xml
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Config/Source/{SourceName}.php   # optional
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Config/Backend/{BackendModelName}.php  # optional
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Config.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Model/ConfigTest.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Model/Config/Source/{SourceName}Test.php  # optional

{output_root}/system-config/{Vendor}_{Module}-{SectionId}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/system-config/`; otherwise default to
`{ctx.docs_root}/system-config/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/system-xml-anatomy.md` — section/group/field
  structure, scope flags, depends, source/backend/frontend model hooks.
- `${CLAUDE_SKILL_DIR}/references/field-types.md` — text, select, multiselect, textarea,
  file, obscure (password), button-via-frontend_model.
- `${CLAUDE_SKILL_DIR}/references/scope-and-paths.md` — default/website/store scope,
  config_path convention, showInDefault/Website/Store flags.
- `${CLAUDE_SKILL_DIR}/references/config-reader-pattern.md` — ScopeConfigInterface +
  ScopeInterface, store-aware getters, isSetFlag for booleans, type casting.
- `${CLAUDE_SKILL_DIR}/references/encrypted-fields.md` — Encrypted backend model,
  type="obscure", reading via getValue + decrypt.
- `magento2-context/references/naming.md` — naming conventions (including config path).
- `magento2-context/references/tdd-discipline.md` — shared test-first RED/GREEN loop.
- `magento2-context/references/php-coding-style.md` — PER-CS + Magento coding style.
- `magento2-context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/system.xml` → `etc/adminhtml/system.xml` (merge)
- `templates/config.xml` → `etc/config.xml` (merge)
- `templates/acl.xml` → `etc/acl.xml` (merge)
- `templates/source-model.php` → `Model/Config/Source/{SourceName}.php`
- `templates/backend-model.php` → `Model/Config/Backend/{BackendModelName}.php`
- `templates/config-reader.php` → `Model/Config.php`
- `templates/test-config-reader-unit.php` → `Test/Unit/Model/ConfigTest.php`
- `templates/test-source-model-unit.php` → `Test/Unit/Model/Config/Source/{SourceName}Test.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. Every token used must be in the
Registry there — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- All generated files pass `php -l` / `xmllint --noout`.
- Config paths match the pattern `{vendor_lower}_{module_lower}/{GroupId}/{FieldId}`.
- Secrets use `type="obscure"` + Encrypted backend model.
- No raw `ScopeConfigInterface` usage outside the typed reader.
- ACL resource `{Vendor}_{Module}::config` is declared.
- Unit test mocks `ScopeConfigInterface`, asserts exact path + scope, asserts type cast.
- Source model test asserts `toOptionArray()` returns the correct array shape.
- `magento2-module-review --diff` returns zero Critical/High findings.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| Before (if module absent) | `magento2-module-create` |
| Form for config data (not store config) | `magento2-adminhtml-form` |
| After | `magento2-module-review --diff` |
