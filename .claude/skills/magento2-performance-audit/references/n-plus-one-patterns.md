# N+1 Patterns

## Detection

Pattern: a query (Repository->get, Factory + load, attribute fetch) inside a `foreach`
or other loop body where the loop iterates over a collection.

### Concrete signature

```php
foreach ($products as $product) {
    $extra = $this->extraRepository->get($product->getId()); // <-- N+1
    $product->setExtra($extra->getValue());
}
```

## Remediation Patterns

### Pre-fetch by IDs

```php
$ids = array_map(fn ($p) => $p->getId(), $products);
$extras = $this->extraRepository->getList(
    $this->searchCriteriaBuilder->addFilter('product_id', $ids, 'in')->create()
);
$extrasById = [];
foreach ($extras->getItems() as $extra) {
    $extrasById[$extra->getProductId()] = $extra;
}
foreach ($products as $product) {
    $product->setExtra($extrasById[$product->getId()] ?? null);
}
```

Reduces 1+N queries to 2 (the original + the pre-fetch).

### Collection Join

For ORM-friendly cases:

```php
$collection->join(
    ['extra' => 'product_extra_table'],
    'extra.product_id = main_table.entity_id',
    ['extra_value' => 'extra.value']
);
```

Reduces to 1 query.

### GraphQL Batch Resolver

For GraphQL list contexts, use `BatchResolverInterface`:

```php
class ExtraBatchResolver implements BatchResolverInterface
{
    public function resolve(ContextInterface $context, Field $field, array $requests): BatchResponse
    {
        $ids = array_map(fn ($r) => $r->getValue()['product_id'], $requests);
        $extras = $this->extraRepository->getList(
            $this->searchCriteriaBuilder->addFilter('product_id', $ids, 'in')->create()
        );
        // map back to requests
        $response = new BatchResponse();
        foreach ($requests as $request) {
            $response->addResponse($request, $extras[$request->getValue()['product_id']] ?? null);
        }
        return $response;
    }
}
```

## Known Magento N+1 Hotspots

| Surface | Symptom | Fix |
|---------|---------|-----|
| Catalog listing page | Per-product price load | Use `addAttributeToSelect(['price', 'special_price'])` |
| Cart / checkout | Per-item tax calculation in loop | Pre-load via `TaxCalculator->getRates(addressList)` |
| Order detail | Per-item discount load | Use `OrderItemRepository->getList` with filter |
| GraphQL `products.reviews` | Per-product review fetch | `BatchResolverInterface` |
| Admin grid | Per-row child status load | Add a SQL join in the listing data provider |

## Severity by Context

| Context | Severity |
|---------|---------|
| Storefront critical path (home, category, product, cart, checkout) | High or Critical |
| GraphQL with list results | High |
| Admin grid | Medium |
| Cron / queue iteration | Medium |
| Setup patches | Low (one-shot) |
| Unit tests | n/a (don't audit tests) |
