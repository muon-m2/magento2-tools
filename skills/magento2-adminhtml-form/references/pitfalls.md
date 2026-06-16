# Pitfalls — the silent admin-form failures

Admin forms fail *quietly*: they render but do nothing. This table is the diagnostic checklist; each
row is a real failure mode (community + core issue tracker [S16]) the templates are built to avoid.

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| **Blank form** (fields render, no data on Edit) | The five-name **naming contract** disagrees, or `getData()` not keyed by id | Make namespace / provider / dataSource / dataProvider / `<uiComponent>` all `{entity}_form*`; return `[$id => [...]]`. See form-xml-anatomy.md, dataprovider-patterns.md |
| **Save creates empty/garbage rows** | Posted data unwrapped wrongly, or empty id not nulled | UI form posts **flat**; `setData($post)` directly; set empty `{entity}_id` to `null`. See controllers-and-routing.md |
| **Page error on load** | Form `<button>` references a Block class that doesn't exist | Generate `GenericButton` + every referenced button block |
| **New screen / failed save loses input** | No data persistor | Inject `DataPersistorInterface`; Save `set()` on error, DataProvider `get()`+`clear()` |
| **`xmllint` fails on acl.xml** | `translate` attribute on `<resource>` | Remove it; `translate` is valid only on `menu.xml` `<add>` |
| **Blank content area (no form at all)** | Wrong layout handle file name | Name it `<route_id>_<controller>_edit.xml` = `{vendor_lower}_{entity}_{entity}_edit.xml` |
| **WYSIWYG is a plain textarea** | Missing `<wysiwyg>true</wysiwyg>` / `wysiwygConfigData` | Use the canonical wysiwyg field. See uploaders-wysiwyg.md |
| **Uploader shows a path, not a thumbnail** | DataProvider didn't convert path → `{name,url,...}` | Map stored path to the uploader array on load |
| **Field renders but won't bind/save** | `formElement` vs `dataType` mismatch, or missing `dataScope` | Match the pair; set `dataScope` to the column. See field-types.md |
| **Modifier field flickers / wrong order** | `sortOrder` collision in the pool | Give each modifier a distinct `sortOrder` |
| **dynamicRows empty** | Data supplied as associative, not indexed, array | Re-index the rows array |
| **403/404 on Save or Delete** | ACL resource missing or `ADMIN_RESOURCE` mismatch | Declare the resource in `acl.xml`; match the constant |
| **`deleteById`/`getById` fatal** | Repository uses `delete()`/`get()` instead | Verify the real `{Entity}RepositoryInterface` method names |
| **Commerce features break on Open Source** | Staging/B2B/Page Builder wiring emitted unconditionally | Gate on `{ctx.edition}`. See edition-differences.md |

## The two that cost the most time

1. **Blank form on Edit** — almost always the naming contract or `getData()` shape. Check those two
   first; they account for the majority of "my form is empty" reports.
2. **Save writes nulls** — the form posted flat data but the controller unwrapped a non-existent
   nesting key. Standard UI forms post flat — pass the post straight to `setData()`.

## Sources
- [S16] magento2 issue #22859 (blank form / data provider): https://github.com/magento/magento2/issues/22859
