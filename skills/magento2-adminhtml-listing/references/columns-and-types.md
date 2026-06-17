# Columns and Types

Columns live inside the `<columns name="{LISTING}_columns">` element. Each `<column>` element
maps to one data field. Magento ships several built-in column types; custom column types extend
`Magento\Ui\Component\Listing\Columns\Column`.

## Built-in column types

| Use case | Element | `class` attribute | `dataType` |
|----------|---------|------------------|-----------|
| Plain text / number | `<column>` | (omit — defaults to text) | `text` |
| Date/time | `<column class="Magento\Ui\Component\Listing\Columns\Date">` | see class | `date` |
| Status / select | `<column>` with `<options class="…">` | none | `select` |
| Edit/delete links | `<actionsColumn class="…\Column\{EntityName}Actions">` | see class | — |

### Text column

```xml
<column name="title">
    <settings>
        <filter>text</filter>
        <label translate="true">Title</label>
        <sortOrder>20</sortOrder>
    </settings>
</column>
```

### Date column

```xml
<column name="created_at" class="Magento\Ui\Component\Listing\Columns\Date">
    <settings>
        <filter>dateRange</filter>
        <dataType>date</dataType>
        <label translate="true">Created</label>
        <sortOrder>30</sortOrder>
    </settings>
</column>
```

### Select / status column

```xml
<column name="status">
    <settings>
        <filter>select</filter>
        <dataType>select</dataType>
        <options class="{Vendor}\{ModuleName}\Model\Source\Status"/>
        <label translate="true">Status</label>
        <sortOrder>25</sortOrder>
    </settings>
</column>
```

The `options` class must implement `Magento\Framework\Data\OptionSourceInterface` (or
`toOptionArray()`). Return `[['value' => 1, 'label' => __('Enabled')], ...]`.

### Actions column

```xml
<actionsColumn name="actions" class="{Vendor}\{ModuleName}\Ui\Component\Listing\Column\{EntityName}Actions">
    <settings>
        <indexField>entity_id</indexField>
    </settings>
</actionsColumn>
```

The `indexField` setting tells the column which row field carries the row id used to build the
edit/delete URLs. It must match the `primaryFieldName` declared in the `<dataProvider>` settings
and the actual primary key column in the data. A mismatch produces blank or broken action URLs.
See `templates/column-actions.php` and `references/pairing-with-form.md`.

## Filter types

| Filter value | Rendered as | Appropriate column type |
|-------------|-------------|------------------------|
| `text` | Free-text input | String columns |
| `textRange` | From / to text | ID / numeric columns |
| `select` | Dropdown | Status / enum columns |
| `dateRange` | Date picker pair | Date columns |

Omit `<filter>` on columns that should not be filterable.

## selectionsColumn (REQUIRED for mass actions)

```xml
<selectionsColumn name="ids">
    <settings>
        <indexField>entity_id</indexField>
    </settings>
</selectionsColumn>
```

This element renders the per-row checkbox and wires it to the mass-action system. Without it,
mass-action checkboxes never appear and the entire massaction block is silently inert. Always
declare it before any `<column>` elements. See `references/mass-actions.md`.

## sortOrder

`sortOrder` controls the column display order within the grid. Use increments of 10 so later
additions can slot between existing columns without renumbering. The `entity_id` / ID column
conventionally gets `sortOrder 10`; domain columns follow.

## Sources
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
- [S4] Adobe — Column component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/column/
- [S5] Adobe — Actions column: https://developer.adobe.com/commerce/frontend-core/ui-components/components/action-column/
