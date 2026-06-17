# Pitfalls — the silent admin-listing failures

Admin grids fail *quietly*: they render the toolbar but show zero rows, or mass actions appear
active but affect nothing. This table is the diagnostic checklist; each row is a real failure
mode the templates are built to avoid.

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| **Empty grid** (toolbar renders, zero rows) | The five-place **naming contract** disagrees — any one of the five `{LISTING}` / `{SOURCE}` strings is misspelled or inconsistent | Make js_config provider / deps dep / dataSource name / dataProvider name / columns spinner all agree exactly; confirm file name = `{LISTING}.xml`. Run `scripts/verify-listing.sh`. See `references/listing-xml-anatomy.md` |
| **Empty grid (SearchResult path)** | `di.xml` collections map key does not exactly equal `{SOURCE}` | Make the `<item name="…">` value byte-identical to `{SOURCE}`. See `references/grid-collection.md` |
| **Mass actions inert** | `selectionsColumn` missing — checkboxes never render | Add `<selectionsColumn name="ids"><settings><indexField>entity_id</indexField></settings></selectionsColumn>` as the first child of `<columns>`. See `references/mass-actions.md` |
| **Broken edit/delete URLs** | `actionsColumn indexField` does not match the primary key column in the data | Set `<indexField>` in `<actionsColumn>` to the same field as `primaryFieldName` in `<dataProvider>` |
| **Blank content area** (page renders but grid is missing) | Wrong layout handle file name | Name the file `{vendor_lower}_{module_lower}_{entity}_index.xml`; confirm route id matches |
| **Empty left column (visual artifact)** | `admin-2columns-left` used instead of `admin-1column` | Set `layout="admin-1column"` in `layout-index.xml` |
| **DataProvider returns wrong shape** | `getData()` overridden and returns `[$id => [...]]` (the form shape) instead of the grid shape | For the listing DataProvider, do NOT override `getData()`. `AbstractDataProvider` already returns `['items' => [...], 'totalRecords' => N]` |
| **403/404 on grid data load** | `aclResource` in `<dataSource>` missing or wrong | Set `<aclResource>{Vendor}_{Module}::main</aclResource>` inside `<dataSource>` and grant the resource to the admin role |
| **Mass actions affect 0 records** | Selected rows not resolved via `Filter::getCollection()` | Inject `Magento\Ui\Component\MassAction\Filter` and call `$this->filter->getCollection(...)` — do not read POST ids manually |
| **Commerce-only features on Open Source** | Grid features dependent on `Magento_Staging` or Commerce-tier modules emitted unconditionally | Gate on `{ctx.edition}`. See `references/edition-differences.md` |

## The two that cost the most time

1. **Empty grid** — almost always the five-place naming contract or the SearchResult `di.xml` map
   key. Check those two first; they account for the majority of "my grid is empty" reports. Run
   `scripts/verify-listing.sh` after generation to catch them immediately.
2. **Inert mass actions** — almost always a missing `selectionsColumn`. The toolbar renders and
   no error appears; the only visible symptom is that checkboxes are absent. Add the column and
   the mass actions work instantly.

## Sources
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
- [S6] Adobe — Mass action component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/mass-action/
