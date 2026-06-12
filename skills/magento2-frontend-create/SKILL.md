---
name: magento2-frontend-create
description:
    Frontend-specific scaffolding for Magento 2 — themes, RequireJS modules, Knockout
    components, LESS/CSS, transactional email templates, static asset wiring. Use when
    the user wants to add frontend behaviour or a theme. Detects whether the project
    uses Luma, Hyva, or a custom theme and generates appropriate scaffolds.
---

# Magento 2 Frontend Create

Frontend-specific scaffolding `magento2-module-create` doesn't cover.

## Core Rules

- **Theme-aware.** Detect theme from `magento2-context` (Luma / Hyva / custom). Hyva
  installs use Alpine.js + Tailwind, NOT Knockout/RequireJS.
- **One operation per invocation.** Each call generates ONE of: theme, RequireJS module,
  KO/Alpine component, LESS scaffold, email template, static asset.
- **Layout-driven.** Generated assets include the layout XML to activate them, not just
  the source files.
- **Append-safe.** Never overwrite an existing `requirejs-config.js` or `email_templates.xml`
  — append/merge.
- **Coding style.** Any generated PHP (blocks, ViewModels) follows PER-CS 3.0 as the baseline,
  with the Magento 2 coding standard taking precedence on any conflict; `--standard=Magento2`
  PHPCS is the gate. See `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture theme detection result.

### Phase 1 — Operation Plan

Ask:
- Operation: theme | requirejs-module | ko-component | alpine-component | email-template | static-asset
- Parent theme (for theme operation)
- Module to host (for non-theme operations)

If the theme is Hyva and the user asks for `ko-component`, suggest `alpine-component`
instead — Hyva doesn't run Knockout.

### Phase 2 — Generate

Per operation:

#### Theme

- `theme.xml`, `registration.php`, `composer.json`
- Parent theme reference
- `web/css/source/_extend.less`
- `view.xml`
- `Magento_Theme/layout/default.xml` stub

#### RequireJS module

- `view/frontend/web/js/{name}.js` with module pattern
- `view/frontend/requirejs-config.js` registration (append-safe)

#### Knockout component (UI component)

- Component class extending `uiComponent`
- HTML template
- LESS/CSS sibling
- Layout XML wiring

#### Alpine component (Hyva)

- `view/frontend/templates/{name}.phtml` with `x-data`, `x-show`, etc.
- `view/frontend/layout/{handle}.xml` to render the template

#### Email template

- `view/frontend/email/{name}.html`
- `etc/email_templates.xml` registration (append-safe)
- `etc/config.xml` default path

#### Static asset

- `view/frontend/web/css/...` or `view/frontend/web/images/...`
- Layout reference

### Phase 3 — Verify

- `xmllint --noout` on every XML file.
- `node --check` on every JS file.
- `npm run lint` if the project has a JS linter.

### Phase 4 — Report

Brief: files created + activation commands.

Theme generation requires:
```
{ctx.magento_cli} setup:upgrade
{ctx.magento_cli} setup:static-content:deploy -f
```

## Inputs

```
/magento2-frontend-create <operation> [operation-specific flags]
```

## Outputs

Files written under `{ctx.magento_root}/app/code/{Vendor}/{Module}/view/frontend/` or
`src/app/design/frontend/{Vendor}/{Theme}/`.

## Reference Files

- `references/theme-patterns.md` — Luma inheritance, Hyva inheritance, custom theme.
- `references/requirejs-patterns.md` — module structure, deps, shim.
- `references/ko-component-patterns.md` — UI component vs KO-only.
- `references/alpine-patterns.md` — Hyva Alpine.js patterns.
- `references/less-css-rules.md` — `_module.less` convention, var/mixin scoping.
- `references/email-template-rules.md` — Magento-specific variable syntax, fallback paths.
- `references/static-asset-rules.md` — publish path, fallback chain.

## Templates

- `templates/theme.xml`
- `templates/theme-registration.php`
- `templates/theme-composer.json`
- `templates/theme-view.xml`
- `templates/requirejs-module.js`
- `templates/requirejs-config.js`
- `templates/ko-ui-component.js`
- `templates/ko-ui-component.html`
- `templates/alpine-component.phtml`
- `templates/email-template.html`
- `templates/email_templates.xml`
- `templates/_extend.less`

## Theme Awareness

| Detected theme | Default scaffolds |
|----------------|------------------|
| Luma | Standard Magento patterns; RequireJS-heavy |
| Hyva | Tailwind/Alpine.js; no KO; AlpineJS components instead |
| Custom | Ask user; default to Luma unless told otherwise |

## Acceptance Criteria

- Theme generation produces a working theme registered in `app/design/frontend/`.
- RequireJS modules pass `node --check`.
- KO components render in browser without errors when wired correctly.
- Hyva-detected projects do NOT receive KO scaffolds — Alpine scaffolds instead.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (after Phase 3) | `magento2-module-review` for the host module |
| (caller) | `magento2-feature-implement` Phase 5 (F* tasks) |
