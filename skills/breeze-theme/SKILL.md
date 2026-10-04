---
name: breeze-theme
version: 1.0.2
description: >-
  Scaffold a Swissup Breeze (Breezefront) child theme: theme.xml with a Swissup/breeze-* parent, a
  Breeze-only layout handle, and web/css/breeze/_default.less overrides. Use for a new Breeze child
  or custom theme. Detects Breeze via magento2-tools:context (theme.breeze) and refuses when absent.
  Sibling to magento2-tools:frontend (generic Luma/Hyva/custom themes); this is Breeze-specific.
  Adapt a module: magento2-tools:breeze-adapt; check compatibility: magento2-tools:breeze-compat.
---

# Magento 2 Breeze Child Theme

Scaffolds a [Swissup Breeze](https://breezefront.com/docs/child-theme) child theme. Breeze is a
high-performance frontend framework that replaces RequireJS/Knockout/jQuery with a Cash-based
stack; a Breeze child theme inherits one of the Swissup Breeze parent themes and overrides assets
through the Breeze-specific `web/css/breeze/` directory.

## Core Rules

- **Breeze-required.** Resolve `context` and read `theme.breeze.installed`. If it is
  `false`, do NOT scaffold — print the install path and stop:
  ```
  composer require swissup/breeze-evolution && \
    bin/magento setup:upgrade --safe-mode=1 && \
    bin/magento marketplace:package:install swissup/breeze-evolution
  ```
- **One theme per invocation.** This skill produces exactly one child theme.
- **Append-safe.** Never overwrite an existing `theme.xml` / `registration.php`; if the target
  theme directory already exists, stop and report rather than clobber.
- **Parent is a Breeze theme.** The `<parent>` is `Swissup/breeze-blank`,
  `Swissup/breeze-evolution`, or `Swissup/breeze-enterprise` — default to the detected installed
  parent (`theme.breeze.parent` or the matched `theme.breeze.packages`), else ask.
- **Breeze overrides live in `web/css/breeze/`.** Storefront CSS goes in
  `web/css/breeze/_default.less` (auto-included by Breeze on every page) and uses the `@critical`
  guard. `web/css/source/_extend.less` remains the Luma-side hook for any blank/luma fallback.
- **Coding style.** Any generated PHP follows PER-CS 3.0 with the Magento 2 coding standard taking
  precedence; `--standard=Magento2` PHPCS is the gate. See
  `context/references/php-coding-style.md`.
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `context`. Capture `theme.breeze` (installed / active / parent / packages) and
`php_constraint` / `framework_constraint`. Enforce the Breeze-required rule above.

### Phase 1 — Inputs

Ask (offer detected defaults):
- Vendor (PascalCase, e.g. `Acme`) — default `{ctx.vendor}`.
- Theme name (e.g. `BreezeCustom`).
- Parent theme: `breeze-blank` | `breeze-evolution` | `breeze-enterprise` — default = detected.
- Title (human-readable, shown in admin).

### Phase 2 — Generate

Target: `{ctx.magento_root}/app/design/frontend/{Vendor}/{Theme}/`.

If `bin/magento` is available AND the user opts in, prefer the Breeze generator and then layer the
templated overrides on top:
```
{ctx.magento_cli} breeze:theme:create {vendor_lower}/{theme_lower} --parent=Swissup/breeze-{parent}
```
Otherwise scaffold manually from templates:
- `registration.php` (from `templates/theme-registration.php`)
- `theme.xml` (`templates/theme.xml`; `<parent>Swissup/breeze-{parent}</parent>`)
- `composer.json` (`templates/theme-composer.json`)
- `web/css/breeze/_default.less` (`templates/breeze_default.less`)
- `web/css/source/_extend.less` (`templates/_extend.less`)
- `Magento_Theme/layout/breeze_default.xml` (`templates/breeze_default-layout.xml`)

### Phase 3 — Verify

- `xmllint --noout` on `theme.xml` and the layout file.
- `php -l` on `registration.php`.
- Confirm the parent theme code matches an installed `theme.breeze.packages` entry.
- **Apply the shared module-hygiene baseline (required).** After generating the theme's PHP
  files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/add-license-headers.sh {ctx.magento_root}/app/design/frontend/{Vendor}/{Theme} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (e.g. `registration.php`;
  idempotent — it skips files that already carry it). When adding a `composer.json` `require`
  entry, resolve a **bounded** constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/resolve-dep-constraint.sh <vendor/package>`
  — never `"*"`. See `context/references/module-hygiene.md`.

### Phase 4 — Report

Files created + activation:
```
{ctx.magento_cli} setup:upgrade
{ctx.magento_cli} setup:static-content:deploy -f
```
Then set the theme active in **Content → Design → Configuration** (per store view) or via
`config:set design/theme/theme_id`.

## Inputs

```
/breeze-theme [--vendor=Acme] [--name=BreezeCustom] [--parent=breeze-evolution]
```

## Outputs

A registered Breeze child theme under `{ctx.magento_root}/app/design/frontend/{Vendor}/{Theme}/`.

## Reference Files

- `references/breeze-theme-patterns.md` — directory layout, parent choice, `@critical` LESS
  guard, `web/css/breeze/` vs `web/css/source/` and activation.
- `context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/theme.xml`
- `templates/theme-registration.php`
- `templates/theme-composer.json`
- `templates/breeze_default.less`
- `templates/_extend.less`
- `templates/breeze_default-layout.xml`

## Acceptance Criteria

- The theme registers under `app/design/frontend/{Vendor}/{Theme}/` with a `Swissup/breeze-*`
  parent.
- `theme.xml` and the layout file pass `xmllint --noout`; `registration.php` passes `php -l`.
- `web/css/breeze/_default.less` exists and uses the `@critical` guard.
- The skill refuses (with the install command) when `theme.breeze.installed` is `false`.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `context` |
| (sibling) | `frontend` for non-Breeze themes/components |
| (next) | `breeze-adapt` to adapt modules to the theme |
| (check) | `breeze-compat` to verify a module's Breeze compatibility |
