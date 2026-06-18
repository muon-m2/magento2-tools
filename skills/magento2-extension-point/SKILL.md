---
name: magento2-extension-point
description:
    Wire behaviour onto an *existing* Magento 2 class without editing it — a **plugin**
    (before/after/around interceptor + di.xml), an **observer** (events.xml + Observer),
    or a **preference**. Use when the user wants to intercept a core/3rd-party method,
    react to an event, or swap an implementation. For a whole new module use
    `magento2-module-create`; for multi-surface work use `magento2-feature-implement`.
---

# Magento 2 Extension Point

Wire behaviour onto an existing Magento 2 class without editing it. Three modes:

- **plugin** — before/after/around interceptor declared in `di.xml`
- **observer** — `Observer` class reacting to a dispatched event declared in `events.xml`
- **preference** — replaces an interface or class binding in the DI container

## Core Rules

- **Never edit the target class.** All wiring is additive — the target file is read-only.
- **Lightest mechanism first.** Prefer observer < plugin < preference; reach for the
  lightest one that expresses the intent.
- **`around` only when before+after cannot express it.** `around` wraps `$proceed` and
  blocks every other interceptor on the chain; it is expensive and fragile.
- **Never plugin `final`, `private`, or `static` methods.** Magento's interceptor
  generator skips them silently, producing a proxy that doesn't intercept. Never plugin
  data interfaces (they are generated, not real classes).
- **Area-scope the wiring.** Use `etc/di.xml` for global scope; use
  `etc/{area}/di.xml` or `etc/{area}/events.xml` for area-specific behaviour.
  See `${CLAUDE_SKILL_DIR}/references/area-scoping.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2
  coding standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the
  gate. See `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture the
JSON as `{ctx}`. Abort if `{ctx.magento_root}` is unresolved. If the target module does
not exist, offer `magento2-module-create` first.

### Phase 1 — Resolve Inputs

Ask for any missing values in one batch. Required inputs differ by mode:

**Plugin mode**

| Input | Default | Notes |
|-------|---------|-------|
| Target FQCN | (ask) | Fully-qualified class name to intercept |
| Method | (ask) | Public, non-final, non-static method name |
| Plugin type | (ask) | `before`, `after`, or `around` |
| Plugin class name | (ask) | PascalCase, placed in `Plugin/` |
| Plugin name (DI) | (ask) | snake_case identifier in di.xml |
| SortOrder | 10 | Integer; lower runs first |
| Area | global | `global`, `frontend`, `adminhtml`, `webapi_rest`, `graphql`, `crontab` |
| Module | (ask) | Existing `{Vendor}_{Module}` |

**Observer mode**

| Input | Default | Notes |
|-------|---------|-------|
| Event name | (ask) | e.g. `sales_order_save_after` |
| Observer class name | (ask) | PascalCase, placed in `Observer/` |
| Observer name (XML) | (ask) | snake_case identifier in events.xml |
| Area | global | `global`, `frontend`, `adminhtml`, etc. |
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Dispatched data shape | (ask) | Keys available via `$observer->getData()` / `$observer->getEvent()` |

**Preference mode**

| Input | Default | Notes |
|-------|---------|-------|
| `for` (interface/class FQCN) | (ask) | Interface or class being replaced |
| Replacement class name | (ask) | PascalCase, placed in `Model/` |
| Area | global | `global`, `frontend`, `adminhtml`, etc. |
| Module | (ask) | Existing `{Vendor}_{Module}` |

See `${CLAUDE_SKILL_DIR}/references/plugin-types.md`,
`${CLAUDE_SKILL_DIR}/references/observer-events.md`,
`${CLAUDE_SKILL_DIR}/references/preference-vs-plugin.md`, and
`${CLAUDE_SKILL_DIR}/references/area-scoping.md`.

### Phase 2 — Plan

Present every file to create or modify. Typical file sets per mode:

**Plugin:** `Plugin/{PluginName}.php`, `etc/{area}/di.xml` (merge),
`Test/Unit/Plugin/{PluginName}Test.php`

**Observer:** `Observer/{ObserverName}.php`, `etc/{area}/events.xml` (merge),
`Test/Unit/Observer/{ObserverName}Test.php`

**Preference:** `Model/{EntityName}.php`, `etc/{area}/di.xml` (merge)

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing test (RED).** Before generating implementation code, write a
test that expresses the expected behaviour and watch it fail for the right reason:

- **Plugin:** unit test mocking the subject class and asserting the interceptor
  transforms the argument or return value as intended.
- **Observer:** unit test mocking `\Magento\Framework\Event\Observer` and the inner
  `\Magento\Framework\Event`, asserting `execute()` acts on the event payload.
- **Preference:** integration test asserting
  `\Magento\TestFramework\Helper\Bootstrap::getObjectManager()->get({for})` returns an
  instance of the replacement class. When no test DB is available, write a unit test
  asserting the replacement class can be instantiated.

Follow `magento2-context/references/tdd-discipline.md`. Run the test and confirm it
fails for the right reason (not a setup or autoload error).

**3B — Generate implementation (GREEN).** Write the minimal code to make the 3A test
pass, using the templates:

- `${CLAUDE_SKILL_DIR}/templates/plugin-class.php`
- `${CLAUDE_SKILL_DIR}/templates/plugin-di.xml`
- `${CLAUDE_SKILL_DIR}/templates/observer-class.php`
- `${CLAUDE_SKILL_DIR}/templates/events.xml`
- `${CLAUDE_SKILL_DIR}/templates/preference-di.xml`
- `${CLAUDE_SKILL_DIR}/templates/preference-class.php`

For test files: `${CLAUDE_SKILL_DIR}/templates/test-plugin-unit.php` and
`${CLAUDE_SKILL_DIR}/templates/test-observer-unit.php`.

### Phase 4 — Verify

- `php -l` on every generated `.php` file.
- `xmllint --noout` on every generated `.xml` file.
- Run the Phase 3A test with `{ctx.runner} vendor/bin/phpunit` and confirm it now
  **passes** (it failed before 3B); run the module's suite to confirm nothing else broke.
- Run `magento2-module-review --diff` (gate: zero Critical/High findings).
- Consult `${CLAUDE_SKILL_DIR}/references/pitfalls.md` before declaring Phase 4 done.

### Phase 5 — Report

Write a brief Markdown report to
`.docs/extension-points/{Vendor}_{Module}-{mode}-{slug}-{date}.md`:

- Files generated
- Test path + red→green evidence
- Area scope chosen and rationale
- `bin/magento setup:upgrade` command if `registration.php` / `di.xml` changed
- Cache flush hint (`bin/magento cache:flush`)

## Inputs

```
/magento2-extension-point --mode=plugin --target=Magento\Checkout\Model\Cart --method=addProduct --type=after --module=Acme_Checkout
/magento2-extension-point --mode=observer --event=sales_order_save_after --module=Acme_Sales
/magento2-extension-point --mode=preference --for=Magento\Catalog\Api\ProductRepositoryInterface --module=Acme_Catalog
```

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Plugin/{PluginName}.php           # plugin mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/{area}/di.xml                 # plugin / preference mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/Observer/{ObserverName}.php       # observer mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/{area}/events.xml             # observer mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/{EntityName}.php            # preference mode
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Plugin/{PluginName}Test.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Observer/{ObserverName}Test.php

.docs/extension-points/{Vendor}_{Module}-{mode}-{slug}-{date}.md
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under
`{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/plugin-types.md` — before/after/around semantics,
  return-value and argument rules, `$proceed` cost, sortOrder.
- `${CLAUDE_SKILL_DIR}/references/observer-events.md` — common dispatched events,
  Observer/Event payload access, area-scoped events.xml.
- `${CLAUDE_SKILL_DIR}/references/preference-vs-plugin.md` — decision matrix, why
  preferences are a last resort, conflict risk.
- `${CLAUDE_SKILL_DIR}/references/area-scoping.md` — which di.xml/events.xml to use:
  global vs frontend/adminhtml/webapi_rest/graphql/crontab.
- `${CLAUDE_SKILL_DIR}/references/pitfalls.md` — final/private/static, data-interface
  plugins, around-proceed perf, observer idempotency, no DB writes in hot events.
- `magento2-context/references/tdd-discipline.md` — shared test-first RED/GREEN loop.
- `magento2-context/references/php-coding-style.md` — PER-CS + Magento coding style.
- `magento2-context/references/naming.md` — naming conventions.

## Templates

- `templates/plugin-class.php` → `Plugin/{PluginName}.php`
- `templates/plugin-di.xml` → `etc/{area}/di.xml` (merge)
- `templates/observer-class.php` → `Observer/{ObserverName}.php`
- `templates/events.xml` → `etc/{area}/events.xml` (merge)
- `templates/preference-di.xml` → `etc/{area}/di.xml` (merge)
- `templates/preference-class.php` → `Model/{EntityName}.php`
- `templates/test-plugin-unit.php` → `Test/Unit/Plugin/{PluginName}Test.php`
- `templates/test-observer-unit.php` → `Test/Unit/Observer/{ObserverName}Test.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. Every token used must be in the
Registry there — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- The target class is never edited.
- Correct mechanism chosen (lightest possible for the use case).
- `around` plugin is used only when before/after cannot express the logic.
- No plugin on a `final`, `private`, `static` method or data interface.
- XML is area-scoped to the narrowest applicable scope.
- A failing unit test (or integration test for preference) was written and watched to
  fail before implementation, and passes after.
- All generated files pass `php -l` / `xmllint --noout`.
- `magento2-module-review --diff` returns zero Critical/High findings.

## Common Pitfalls Handled

See `${CLAUDE_SKILL_DIR}/references/pitfalls.md` for the full list. Key ones:

| Pitfall | How the skill avoids it |
|---------|------------------------|
| Plugging a `final`/`private`/`static` method | Phase 1 validates the method signature |
| Plugging a data interface | Phase 1 rejects FQCN matching `*/Api/Data/*Interface` |
| Unnecessary `around` | Phase 1 asks for justification; before/after suggested first |
| Global di.xml when only frontend needs it | Phase 1 asks for area; defaults to global with warning |
| DB writes inside a hot event observer | Reference pitfalls.md; Phase 4 module-review gate |

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| Before (if module absent) | `magento2-module-create` |
| (caller) | `magento2-feature-implement` Phase 5 — when a blueprint declares interception tasks |
| After | `magento2-module-review --diff` |
