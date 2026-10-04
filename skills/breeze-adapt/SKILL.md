---
name: breeze-adapt
version: 1.0.2
description: >-
  Adapt an existing Magento 2 module to Swissup Breeze by generating a separate companion module
  {Vendor}_{Module}Breeze. Never edits the target, so it works on vendor/ modules. Use to make a
  module work with Breeze. Needs Breeze (magento2-tools:context theme.breeze). Unlike
  magento2-tools:extension-point (plugins/observers/preferences), this builds the Breeze frontend
  adapter; run magento2-tools:breeze-compat first. New theme: magento2-tools:breeze-theme.
---

# Magento 2 Breeze Module Adapt

Generates a **companion integration module** that makes an existing module work with a
[Swissup Breeze](https://breezefront.com/docs/custom-module) theme, without touching the target
module. Breeze replaces RequireJS/Knockout/jQuery with a Cash-based stack, so a Luma module's
frontend JS usually needs a Breeze adapter (or Better Compatibility mode).

## Core Rules

- **Breeze-required.** Resolve `context`; if `theme.breeze.installed` is `false`, do NOT
  generate — print the install path and stop:
  ```
  composer require swissup/breeze-evolution && \
    bin/magento setup:upgrade --safe-mode=1 && \
    bin/magento marketplace:package:install swissup/breeze-evolution
  ```
- **Separate companion module — never edit the target.** Output goes to a new
  `{Vendor}_{Module}Breeze` module so the adapter survives target upgrades and works even when the
  target lives in read-only `vendor/`.
- **Sequence after the target and Swissup_Breeze.** `module.xml` declares
  `<sequence>` on `{Vendor}_{Module}` and `Swissup_Breeze` so layout/JS load in the right order.
- **One target per invocation.** Adapt one module per run.
- **Append-safe.** If the companion module already exists, merge into `breeze_default.xml` and add
  new widget files — never clobber existing adapter code.
- **Breeze-only layout.** Layout files are `breeze_`-prefixed so they never affect blank/luma.
- **Prefer Better Compatibility when a port isn't warranted.** For a module that only needs its
  existing RequireJS to keep working, register it under the `breeze.js` `better_compatibility`
  array instead of hand-porting every widget. See `references/breeze-js-conversion.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 with Magento 2 precedence;
  `--standard=Magento2` PHPCS is the gate (`context/references/php-coding-style.md`).
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `context`. Capture `theme.breeze`, `vendor`, `php_constraint`,
`framework_constraint`. Enforce the Breeze-required rule.

### Phase 1 — Scope

- Identify the target module `{Vendor}_{Module}` and locate it (`app/code` or `vendor/`).
- Recommended: run `breeze-compat` on the target first; its findings tell you which
  surfaces need adapting (which widgets to port vs. enable Better Compatibility for).
- Decide surfaces: JS widgets (port) and/or Better Compatibility (register), CSS (move to
  `breeze/_default.less`), layout (move blocks).
- Name the companion: `{Vendor}_{Module}Breeze` under
  `{ctx.magento_root}/app/code/{Vendor}/{Module}Breeze/`.

### Phase 2 — Generate companion module

From templates:
- `registration.php` (`templates/registration.php`) — registers `{Vendor}_{Module}Breeze`.
- `etc/module.xml` (`templates/module.xml`) — `<sequence>` target + `Swissup_Breeze`.
- `composer.json` (`templates/composer.json`).
- `view/frontend/layout/breeze_default.xml` (`templates/breeze_default.xml`) — registers the
  widget component (and a commented `better_compatibility` alternative) on `breeze.js`.
- `view/frontend/web/css/breeze/_default.less` (`templates/breeze_default.less`) — `@critical`.
- `view/frontend/web/js/breeze/widget.js` (`templates/breeze-widget.js`) — one Cash `$.widget`
  stub per detected widget, each with a TODO pointing at the original source.

### Phase 3 — Enable & verify

- `xmllint --noout` on XML, `node --check` on JS, `php -l` on PHP.
- **Apply the shared module-hygiene baseline (required).** After generating the companion
  module's PHP files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module}Breeze {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files
  that already carry it, so re-running when merging into an existing companion is safe). When
  adding a `composer.json` `require` entry, resolve a **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/resolve-dep-constraint.sh <vendor/package>`
  — never `"*"`. See `context/references/module-hygiene.md`.
- ```
  {ctx.magento_cli} setup:upgrade
  {ctx.magento_cli} setup:static-content:deploy -f
  ```
- Test on a Breeze page with `?breeze=1&compat=1` (debug mode) and watch the console for the
  module's activation message.

## Inputs

```
/breeze-adapt <Vendor_Module> [--better-compatibility-only]
```

## Outputs

A companion module under `{ctx.magento_root}/app/code/{Vendor}/{Module}Breeze/`.

## Reference Files

- `references/breeze-module-patterns.md` — companion-module rationale, `<sequence>`, the `breeze_`
  layout rule, `web/css/breeze/` auto-include, `breeze.js` registration (component vs
  `better_compatibility`).
- `references/breeze-js-conversion.md` — mapping RequireJS/Knockout/jQuery widgets to Breeze Cash
  `$.widget`, `data-mage-init`/`x-magento-init` handling, Cash gaps.
- `context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/registration.php`
- `templates/module.xml`
- `templates/composer.json`
- `templates/breeze_default.xml`
- `templates/breeze_default.less`
- `templates/breeze-widget.js`

## Acceptance Criteria

- A companion `{Vendor}_{Module}Breeze` module is generated; the target module is unchanged.
- `module.xml` sequences the target and `Swissup_Breeze`.
- XML passes `xmllint`, JS passes `node --check`, PHP passes `php -l`.
- The skill refuses (with the install command) when `theme.breeze.installed` is `false`.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `context` |
| 1 (recommended first) | `breeze-compat` to find what needs adapting |
| (sibling) | `extension-point` for non-Breeze plugin/observer/preference wiring |
| (theme) | `breeze-theme` for a new Breeze theme |
