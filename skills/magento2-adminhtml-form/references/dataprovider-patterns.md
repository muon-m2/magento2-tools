# DataProvider Patterns

The form's `<dataSource>` aggregates a class implementing
`Magento\Framework\View\Element\UiComponent\DataProvider\DataProviderInterface`. Its data is shared
with every child component of the form, keyed via `requestFieldName`/`primaryFieldName`. ([S1])

## Which base class

| Need | Base class |
|------|-----------|
| Simple form, fields declared in XML (default) | `Magento\Ui\DataProvider\AbstractDataProvider` |
| Fields built/altered dynamically, or modifiers | `Magento\Ui\DataProvider\ModifierPoolDataProvider` |

`ModifierPoolDataProvider` extends `AbstractDataProvider` and accepts a `pool` argument; use it only
when you actually add modifiers (see modifier-patterns.md). Default to `AbstractDataProvider`. ([S3], [S4], [S8])

## The exact `getData()` shape (resolves "blank form on Edit")

`getData()` MUST return data **keyed by entity id**, each row a **flat** `field => value` map:

```php
$this->loadedData[$model->getId()] = $model->getData();   // [42 => ['title' => …, 'content' => …]]
```

The UI form picks the row whose id matches the `requestFieldName` request param. The canonical
`Magento\Cms` Block/Page DataProvider loads the whole collection and keys by id — fine for admin-sized
tables; for very large tables, filter the collection by the request id instead.

## DataPersistor (resolves "New screen / failed save loses input")

Inject `Magento\Framework\App\Request\DataPersistorInterface`. After a failed `Save`, the controller
stashes the posted data under a key (`{vendor_lower}_{entity}`); `getData()` reads it back into a new
empty item and clears it:

```php
$persisted = $this->dataPersistor->get('{vendor_lower}_{entity}');
if (!empty($persisted)) {
    $model = $this->collection->getNewEmptyItem();
    $model->setData($persisted);
    $this->loadedData[$model->getId()] = $model->getData();
    $this->dataPersistor->clear('{vendor_lower}_{entity}');
}
```

The same key string MUST match the Save controller's `dataPersistor->set(...)`.

## Constructor signature

`AbstractDataProvider` is constructed with `$name, $primaryFieldName, $requestFieldName` (passed by
the framework from the `<dataProvider>` settings), then your injected deps, then `$meta`, `$data`.
Assign `$this->collection` before `parent::__construct()`. See `templates/data-provider.php`.

## Sources
- [S1] Adobe — Form component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/form/
- [S3] Adobe — Modifier concept: https://developer.adobe.com/commerce/frontend-core/ui-components/concepts/modifier/
- [S4] Adobe — Form data provider: https://developer.adobe.com/commerce/frontend-core/ui-components/components/form-data-provider/
- [S8] Smile-SA seller DataProvider: https://github.com/Smile-SA/magento2-module-seller/blob/master/Ui/Component/Seller/Form/DataProvider.php
