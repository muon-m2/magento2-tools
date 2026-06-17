# Pairing with the Edit Form

The listing and the edit form are two separate skills that share the same routes, ACL resource,
and menu entry. The listing's actions column links to the form's `edit` and `delete` routes; the
form's back button and save redirect return to the listing. This pairing is by convention; either
can be generated standalone.

## Actions column routes

`templates/column-actions.php` builds per-row edit and delete URLs using constants:

```php
private const URL_EDIT   = '{vendor_lower}_{module_lower}/{entity}/edit';
private const URL_DELETE = '{vendor_lower}_{module_lower}/{entity}/delete';
```

These paths must match the form's controller routes:

- Edit: `Controller/Adminhtml/{EntityName}/Edit.php`
- Delete: `Controller/Adminhtml/{EntityName}/Delete.php`

When generating the listing alongside an existing form, confirm the form's `routes.xml` route id
matches `{vendor_lower}_{module_lower}`. The listing and form share one `routes.xml`.

## Add-New button route

The `<button name="add">` in `listing.xml` points to `*/*/new`, which routes to the form's
`Controller/Adminhtml/{EntityName}/NewAction.php`. The form skill generates that controller;
confirm it exists before enabling the button.

## Reusing acl/menu/routes

When `magento2-adminhtml-form` has already created:

- `etc/adminhtml/routes.xml`
- `etc/acl.xml`
- `etc/adminhtml/menu.xml`

**Do not overwrite them.** The listing skill:

1. Reads the existing `routes.xml` to confirm the route id matches `{vendor_lower}_{module_lower}`.
2. Merges the listing's ACL resource into `acl.xml` only if it is absent.
3. Leaves `menu.xml` unchanged — the form's menu entry is the shared entry point.

When generating the listing standalone (no form exists), create all three files using the
listing's templates.

## Layout uses `admin-1column`

The listing layout (`layout-index.xml`) must declare `layout="admin-1column"`:

```xml
<page layout="admin-1column">
```

This is the full-width admin layout. Do **not** use `admin-2columns-left` — it adds a blank left
sidebar and is meant for settings screens, not grids.

The edit form layout (`layout-edit.xml`) uses the default (no `layout` attribute needed for
`admin-2columns-left` equivalent) or `admin-1column` depending on whether a left sidebar is
wanted. That is the form skill's concern; the listing always uses `admin-1column`.

## Standalone listing (no form)

If the entity has no edit form yet:

- Omit the `edit` link in the actions column (or link to a placeholder URL).
- Omit the `<button name="add">` in `listing.xml`, or comment it out.
- Note in the Phase 5 report that the edit form is a gap to fill with `magento2-adminhtml-form`.

## Sources
- [S8] Adobe — Admin controllers: https://developer.adobe.com/commerce/php/development/components/controllers/
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
