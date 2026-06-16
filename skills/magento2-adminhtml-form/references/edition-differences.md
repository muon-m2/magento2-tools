# Edition Differences — Open Source vs Adobe Commerce

The core declarative form mechanism (form XML, DataProvider, Modifier/Pool, fields) is **identical**
across Magento Open Source and Adobe Commerce. Detect `{ctx.edition}` and gate the Commerce-only
surfaces below — never emit them on Open Source.

## Content Staging (Adobe Commerce only)

Commerce augments admin forms with **scheduled updates**: a "Schedule New Update" control and
staging-aware persistence (the staging "module pattern" + `Magento_CatalogStaging` /
`Magento_Staging`). Open Source has no staging tab and no `update_id` dimension. If the entity should
support staged changes on Commerce, that is a separate, larger surface — do not scaffold it by
default. ([S18], [S19])

## B2B company forms (Adobe Commerce only)

The B2B module set ships admin forms such as company-account management
(`account-company-manage`). These are Commerce + B2B-module specific. ([S20])

## Page Builder

The Page Builder editor (a WYSIWYG adapter / `pagebuilder` formElement) ships via
`Magento_PageBuilder`. It is **bundled by default only in Adobe Commerce**; on Open Source it is an
optional install. Treat a Page Builder field as conditionally available — fall back to the standard
`wysiwyg` element (uploaders-wysiwyg.md) when `Magento_PageBuilder` is absent.

## Practical rule for the skill

1. Read `{ctx.edition}` in Phase 0.
2. Offer staging / B2B / Page Builder field options **only** when edition is `adobe-commerce`.
3. When generating on Open Source, the form, DataProvider, controllers, and fields are all standard —
   no edition-specific wiring is emitted.

## Sources
- [S18] Adobe — Staging patterns / module: https://developer.adobe.com/commerce/admin-developer/pattern-library/staging-patterns/module/
- [S19] Adobe — module-catalog-staging: https://developer.adobe.com/commerce/php/module-reference/module-catalog-staging
- [S20] Experience League — B2B company account: https://experienceleague.adobe.com/en/docs/commerce-admin/b2b/companies/account-company-manage
