# Controllers, Routing, ACL & Layout

## The controller set

| Action | Class | Interface | Purpose |
|--------|-------|-----------|---------|
| `index` | `Index.php` | `HttpGetActionInterface` | renders the listing page |
| `massDelete` | `MassDelete.php` | `HttpPostActionInterface` | bulk-deletes selected records |
| `massStatus` | `MassStatus.php` | `HttpPostActionInterface` | bulk-toggles status (optional) |

All extend `Magento\Backend\App\Action` and declare
`public const ADMIN_RESOURCE = '{Vendor}_{Module}::main'`.

The edit/delete row actions are handled by the sibling form skill's controllers
(`Controller/Adminhtml/{Entity}/Edit.php` and `Delete.php`). The listing skill generates only
the listing-specific controllers. See `references/pairing-with-form.md`.

## Index controller

`Index.php` is a read-only `HttpGetActionInterface` controller. It creates a result page, sets
the active menu item, and prepends a title. The grid itself is rendered by the layout XML — the
controller does not load data. See `templates/controller-index.php`.

```php
$page = $this->pageFactory->create();
$page->setActiveMenu('{Vendor}_{ModuleName}::main');
$page->getConfig()->getTitle()->prepend(__('{EntityName} List'));
return $page;
```

## Mass-action controllers

`MassDelete` and `MassStatus` are `HttpPostActionInterface` controllers. They:

1. Call `$this->filter->getCollection($this->collectionFactory->create())` to resolve the
   selected rows. Never read the selected ids from POST directly.
2. Loop the collection and apply the operation.
3. Add a success message via `$this->messageManager->addSuccessMessage(...)`.
4. Redirect to `*/*/` (the listing) via `$this->resultRedirectFactory->create()->setPath('*/*/');`.

See `templates/controller-mass-delete.php`, `templates/controller-mass-status.php`, and
`references/mass-actions.md` for the full bodies and the partial-failure / Model::save() pitfalls.

## Routing

`etc/adminhtml/routes.xml` declares `<route id="{vendor_lower}_{module_lower}" frontName="…">`.
The **route id** drives `*/*/` relative paths and the layout handle file name. See
`templates/routes.xml`.

If a sibling `magento2-adminhtml-form` already created `routes.xml` for the same module, **reuse
it** — do not overwrite or duplicate it.

## ACL

`etc/acl.xml` declares the resource named by `ADMIN_RESOURCE`. `acl.xsd` allows only `id`,
`title`, `sortOrder`, and `disabled` on `<resource>` — **no `translate` attribute** (valid only
on `menu.xml <add>`). Merge into any existing `acl.xml`. See `templates/acl.xml`.

The `aclResource` in `listing.xml`'s `<dataSource>` gates the grid data endpoint. The `Index`
and mass-action controllers check `ADMIN_RESOURCE` at dispatch time. Use the same resource string
in all three places so that granting the resource once covers the full grid workflow.

## Layout handle derivation (resolves "empty page content")

The listing layout file must be named to match the handle
`<route_id>_<controller>_<action>` → `{vendor_lower}_{module_lower}_{entity}_index.xml`.

The body adds the listing uiComponent to the `content` container:

```xml
<page layout="admin-1column">
    <update handle="styles"/>
    <body>
        <referenceContainer name="content">
            <uiComponent name="{vendor_lower}_{module_lower}_{entity}_listing"/>
        </referenceContainer>
    </body>
</page>
```

Use `layout="admin-1column"` — a full-width single-column admin layout. `admin-2columns-left`
leaves a blank left sidebar that is distracting and wrong for a grid. See `templates/layout-index.xml`.

## Sources
- [S8] Adobe — Admin controllers: https://developer.adobe.com/commerce/php/development/components/controllers/
- [S9] Adobe — ACL: https://developer.adobe.com/commerce/php/development/components/access-control-list-rules/
