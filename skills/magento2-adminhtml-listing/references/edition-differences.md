# Edition Differences — Open Source vs Adobe Commerce

A basic adminhtml listing/grid built with the default `AbstractDataProvider` wiring is
**fully compatible with Magento Open Source**. Detect `{ctx.edition}` in Phase 0 and gate any
Commerce-only features; never emit them on Open Source.

## Core grid — Open Source compatible

The following surfaces are available on both editions:

- `ui_component/{entity}_listing.xml` with all standard toolbar widgets (bookmarks, columnsControls, filters, massaction, paging).
- `AbstractDataProvider` + `CollectionFactory` wiring.
- `SearchResult` + `di.xml` grid collection.
- `selectionsColumn`, standard column types (text, date, select), `actionsColumn`.
- Mass-action controllers (MassDelete, MassStatus).
- `etc/adminhtml/routes.xml`, `etc/acl.xml`, `etc/adminhtml/menu.xml`.

## Adobe Commerce — additional surfaces

| Feature | Commerce requirement | Notes |
|---------|---------------------|-------|
| Inline editing | Available both editions (basic); advanced cell types may differ | Flag if custom cell types depend on Commerce modules |
| Grid export (CSV / XML) | Open Source — basic; Commerce — extended export profiles | `<exportButton>` works on both, but `Magento_ScheduledImportExport` is Commerce-only |
| Content Staging column | `Magento_Staging` — **Adobe Commerce only** | Never emit staging column wiring on Open Source |
| Full-text grid search (`filterSearch`) | Open Source compatible when using standard collection | Elasticsearch-backed full-text search requires Commerce-tier Elasticsearch config |

## Practical rule for the skill

1. Read `{ctx.edition}` in Phase 0.
2. Offer export profiles, staging columns, or full-text `filterSearch` **only** when edition is `adobe-commerce`.
3. When generating on Open Source, emit only standard toolbar widgets and column types — no edition-specific wiring.
4. Document any deferred Commerce-only surface in the Phase 5 report.

## Sources
- [S10] Adobe — Commerce vs Open Source features: https://experienceleague.adobe.com/en/docs/commerce-operations/release/features
- [S11] Adobe — Staging patterns: https://developer.adobe.com/commerce/admin-developer/pattern-library/staging-patterns/module/
