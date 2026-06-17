# Listing XML Anatomy & the Naming Contract

The admin listing is a declarative UI component at
`{Vendor}/{Module}/view/adminhtml/ui_component/{vendor_lower}_{module_lower}_{entity}_listing.xml`,
root element `<listing>`, bound to
`urn:magento:module:Magento_Ui:etc/ui_configuration.xsd`. It is rendered by a layout that
includes `<uiComponent name="{vendor_lower}_{module_lower}_{entity}_listing"/>`. ([S1])

## The naming contract (prevents the empty grid)

These five names MUST agree. A single mismatch renders an empty grid with **no error message**
— the #1 time-sink for grid development. ([S1], pitfalls.md)

Define two short-hand names first:

```
LISTING = {vendor_lower}_{module_lower}_{entity}_listing
SOURCE  = {LISTING}_data_source
```

| # | Where in listing.xml | Required value |
|---|----------------------|----------------|
| 1 | `<argument name="js_config">` → `provider` item | `{LISTING}.{SOURCE}` |
| 2 | `<settings>` → `<deps>` → `<dep>` | `{LISTING}.{SOURCE}` |
| 3 | `<dataSource name="…">` | `{SOURCE}` |
| 4 | `<dataProvider name="…">` (nested inside dataSource) | `{SOURCE}` |
| 5 | `<columns name="…">` (referenced by `<spinner>`) | `{LISTING}_columns` |

The file name itself must be `{LISTING}.xml` so the layout handle resolves correctly.

All five of these are generated from the same token set; the skill enforces agreement by
construction. `scripts/verify-listing.sh` re-checks agreement after generation.

## Top-level structure

```
<listing>
  <argument name="data">          ← js_config.provider
  <settings>
    <buttons>                     ← Add-New button (*/*/new)
    <spinner>{LISTING}_columns</spinner>
    <deps><dep>{LISTING}.{SOURCE}</dep></deps>
  <dataSource name="{SOURCE}" component="Magento_Ui/js/grid/provider">
    <settings>
      <storageConfig><param name="indexField">{entity}_id</param></storageConfig>
      <updateUrl path="mui/index/render"/>
    </settings>
    <aclResource>{Vendor}_{Module}::main</aclResource>
    <dataProvider class="…\Ui\DataProvider\{EntityName}DataProvider" name="{SOURCE}">
      <settings>
        <requestFieldName>{entity}_id</requestFieldName>
        <primaryFieldName>{entity}_id</primaryFieldName>
      </settings>
    </dataProvider>
  </dataSource>
  <listingToolbar name="listing_top">    ← toolbar widgets
  <columns name="{LISTING}_columns">
    <selectionsColumn name="ids">        ← REQUIRED for mass actions
    <column name="{entity}_id">
    <actionsColumn name="actions" class="…\Column\{EntityName}Actions">
      <settings><indexField>{entity}_id</indexField></settings>
    </actionsColumn>
  </columns>
</listing>
```

## dataSource

`<dataSource>` must use `component="Magento_Ui/js/grid/provider"` (not the form's
`Magento_Ui/js/form/provider`). The `updateUrl` path `mui/index/render` is the standard AJAX
endpoint. The `aclResource` gates the data endpoint — if the logged-in admin user lacks this
resource, the grid returns an empty result set silently.

## listingToolbar widgets

| Widget | Element name | Purpose |
|--------|-------------|---------|
| Bookmarks | `<bookmark name="bookmarks"/>` | Save/restore column visibility and filter state |
| Column controls | `<columnsControls name="columns_controls"/>` | Show/hide columns toggle |
| Filters | `<filters name="listing_filters"/>` | Filter bar (filter type per column) |
| Mass actions | `<massaction name="listing_massaction">` | Bulk-operation dropdown |
| Paging | `<paging name="listing_paging"/>` | Page-size + page-number controls |

`<settings><sticky>true</sticky></settings>` keeps the toolbar visible while scrolling.

## Cross-module merge

Like form XML, `ui_component/*_listing.xml` files are **merged across modules** by file name.
An extension can declare only additional columns or mass actions without copying the whole file.

## Sources
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
- [S2] Adobe — Data source component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/data-source/
