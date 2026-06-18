# magento2-tools 1.7.0

_Released 2026-06-16_

## Highlights

**New skill: `magento2-adminhtml-form`** — a generator for Magento 2 adminhtml UI-component
**edit forms**, filling the gap between `magento2-module-create` (which emits only a basic admin
stub) and `magento2-frontend-create` (storefront-only). It targets the recurring pain point of
hand-rolling a new admin form and hitting silent "blank form" / "save does nothing" failures.

The plugin now ships **18 skills**.

## What's included

- Declarative `view/adminhtml/ui_component/{entity}_form.xml` + `DataProvider`
  (`AbstractDataProvider` + `DataPersistorInterface`, `getData()` keyed by entity id) +
  New/Edit/Save/Delete controllers + the required button blocks, wired to an existing listing.
- Optional surfaces: modifier/Pool, WYSIWYG, toggle, dynamic-rows, image/file uploader.
- Open-Source-vs-Adobe-Commerce gating (content staging / B2B / Page Builder).
- 17 templates, 10 reference docs, `scripts/verify-form.sh`.
- Built test-first; bakes in the five-name blank-form **naming contract**, flat-post Save
  (empty id → `null`), form-key validation on Save, `acl.xml` without the invalid `translate`
  attribute, and the typed button-block convention shared with `magento2-module-create`.

## Changes since v1.6.0

- **feat(adminhtml-form):** add `magento2-adminhtml-form` skill (#11)
- **fix(adminhtml-form):** apply Copilot review — typed buttons, Delete GET, Save form-key (#11)

Full detail in [CHANGELOG.md](../../CHANGELOG.md).
