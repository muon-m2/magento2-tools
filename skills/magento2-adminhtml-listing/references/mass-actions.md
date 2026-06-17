# Mass Actions

Mass actions let admins apply an operation to multiple rows selected via checkboxes. The system
has four moving parts: the `selectionsColumn`, the `massaction` toolbar widget, the `Filter`
service, and the mass-action controllers.

## selectionsColumn

Declare `<selectionsColumn name="ids">` as the **first element** inside `<columns>`:

```xml
<selectionsColumn name="ids">
    <settings>
        <indexField>entity_id</indexField>
    </settings>
</selectionsColumn>
```

The `indexField` must match the primary key column (`entity_id` or equivalent). Without this
element the checkboxes are never rendered and the entire mass-action system is silently inert —
the massaction toolbar still appears but nothing can be selected. ([S6])

## massaction toolbar widget

Declare `<massaction name="listing_massaction">` inside `<listingToolbar>`. Each child `<action>`
maps to one URL:

```xml
<massaction name="listing_massaction">
    <action name="delete">
        <settings>
            <confirm>
                <message translate="true">Delete selected items?</message>
                <title translate="true">Delete items</title>
            </confirm>
            <url path="*/*/massDelete"/>
            <type>delete</type>
            <label translate="true">Delete</label>
        </settings>
    </action>
</massaction>
```

The `*/*/` notation resolves relative to the current route + controller prefix. The mass-action
URL must correspond to an `HttpPostActionInterface` controller; the UI submits a POST.

### Enable/disable mass actions (status surface)

When the entity has a status field, add enable and disable actions:

```xml
<action name="enable">
    <settings>
        <url path="*/*/massStatus"/>
        <label translate="true">Enable</label>
    </settings>
</action>
<action name="disable">
    <settings>
        <url path="*/*/massStatus"/>
        <label translate="true">Disable</label>
    </settings>
</action>
```

Both actions share the `MassStatus` controller; the specific status value (1 or 0) is injected
via a `di.xml` argument on a virtualType per action if fine-grained control is needed, or the
controller reads a request param. See `templates/controller-mass-status.php`.

## Filter pattern (`Magento\Ui\Component\MassAction\Filter`)

The `Filter` service resolves which collection rows the admin selected. Inject it into every mass
controller:

```php
$collection = $this->filter->getCollection($this->collectionFactory->create());
```

`Filter::getCollection()` applies the grid selection (selected row ids or "select all") to the
fresh collection. Never build the affected collection by reading POST ids manually — the Filter
pattern handles both "select all matching filter" and "select individual rows" transparently.

## MassDelete controller

See `templates/controller-mass-delete.php`. The scaffold loops the filtered collection and calls
`$item->delete()`.

## MassStatus controller

See `templates/controller-mass-status.php`. The scaffold loops the filtered collection, calls
`$item->setData('status', $this->status)`, then `$item->save()`.

## Pitfalls / Notes

**(a) Wrap the delete/save loop in try/catch for partial-failure robustness.**
The scaffold emits a bare loop without error handling. In production code, wrap each
`$item->delete()` (or `$item->save()`) in a `try { … } catch (\Exception $e)` block and call
`$this->messageManager->addErrorMessage(...)` for items that fail. Without this, a single row
failure aborts the entire loop and leaves no error message — the admin sees "0 records deleted"
with no explanation.

```php
foreach ($collection as $item) {
    try {
        $item->delete();
        $deleted++;
    } catch (\Exception $e) {
        $this->messageManager->addErrorMessage(
            __('Could not delete record %1: %2', $item->getId(), $e->getMessage())
        );
    }
}
```

**(b) MassStatus uses `Model::save()` — swap for the entity's repository/resourceModel save in
real code.**
The `MassStatus` template calls `$item->save()` directly on the model. This bypasses any
repository-layer logic (observers, plugins on the repository, etc.) and triggers a deprecation
warning in Magento 2.4+. For production, replace the loop with the entity's
`RepositoryInterface::save()` or call the resource model directly:

```php
// Preferred — use the repository
$this->repository->save($entity->setStatus($this->status));
// Or the resource model
$this->resource->save($item);
```

The scaffold uses `Model::save()` because it has no knowledge of the entity's specific
repository; swap it during integration.

**(c) Missing `selectionsColumn` makes mass actions silently inert.**
The massaction toolbar renders and an action can be "submitted", but with no selected rows the
`Filter` service returns an empty collection and the controller logs "0 records affected." No
error is shown. Always confirm `<selectionsColumn>` is declared before any `<column>` in the
`<columns>` block. ([S6])

## Sources
- [S6] Adobe — Mass action component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/mass-action/
- [S1] Adobe — Listing component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/listing-grid/
