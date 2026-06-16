# Controllers, Routing, ACL & Layout

## The controller set

| Action | Class (file) | Interface | Purpose |
|--------|--------------|-----------|---------|
| `new` | `NewAction.php` (class `NewAction`) | `HttpGetActionInterface` | forwards to `edit` (`New` is reserved) |
| `edit` | `Edit.php` | `HttpGetActionInterface` | renders the form page; 404-redirects a missing id |
| `save` | `Save.php` | `HttpPostActionInterface` | persists; redirect Back or Save-and-Continue |
| `delete` | `Delete.php` | `HttpPostActionInterface` | deletes by id |

All extend `Magento\Backend\App\Action` and declare
`public const ADMIN_RESOURCE = '{Vendor}_{Module}::{entity}'`. See `templates/controller-*.php`.

## Save flow (resolves "Save saves empty rows")

A standard UI form posts **flat** field data; `$this->getRequest()->getPostValue()` returns
`['{entity}_id' => …, …fields]` — do **not** unwrap a `data`/`general` key. Normalise an empty id to
`null` before `repository->save()` so a new record inserts. On `\Exception`, stash the post in the
data persistor and redirect to `*/*/edit` with `_current=true`. ([S4], [S7], [S16])

Save-and-Continue is just the `back` request param: when set, redirect to `*/*/edit` with the saved
id; otherwise redirect to the listing (`*/*/`).

## Repository method names (verify!)

The templates call `getById()`, `save()`, `deleteById()`. Your repository interface may instead expose
`get()` or `delete(EntityInterface $e)`. Confirm the actual `{Entity}RepositoryInterface` and adjust —
a method-name mismatch fatals the Save/Delete controller.

## Routing

`etc/adminhtml/routes.xml` declares `<route id="{vendor_lower}_{entity}" frontName="…">`. The **route
id** (not frontName) drives `*/*/` relative paths and the layout handle. See `templates/routes.xml`.

## ACL (resolves "xmllint fails on acl.xml")

`etc/acl.xml` declares the resource named by `ADMIN_RESOURCE`. `acl.xsd` allows only `id`, `title`,
`sortOrder`, `disabled` on `<resource>` — **no `translate`** (that attribute is valid only on
`menu.xml` `<add>`). Merge into any existing acl.xml. See `templates/acl.xml`, `templates/menu.xml`.

## Layout handle derivation (resolves "blank content area")

The page is rendered by a layout file whose name is the handle
`<route_id>_<controller>_<action>` → `{vendor_lower}_{entity}_{entity}_edit.xml`. `NewAction` forwards
to `edit`, so one edit layout covers both. The body is just
`<referenceContainer name="content"><uiComponent name="{entity}_form"/></referenceContainer>` — no
storefront handles like `<update handle="styles"/>`. See `templates/layout-edit.xml`.

## Sources
- [S4] Adobe — Form data provider: https://developer.adobe.com/commerce/frontend-core/ui-components/components/form-data-provider/
- [S7] Adobe — Custom product creation form: https://developer.adobe.com/commerce/php/tutorials/admin/custom-product-creation-form/
- [S16] magento2 issue #22859: https://github.com/magento/magento2/issues/22859
