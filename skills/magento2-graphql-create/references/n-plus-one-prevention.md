# N+1 Prevention in GraphQL Resolvers

## When N+1 Happens

GraphQL queries naturally fan out: a single client query can request a list of products,
each with reviews, each with author. Naive resolvers issue one query per item:

```graphql
{
  products(filter: {...}) {
    items {
      id
      reviews { id author { name } }
    }
  }
}
```

A standard resolver fires `reviews` once per product (N queries), then `author` once
per review (M queries). Total: 1 + N + N*M queries.

## The Fix: BatchResolverInterface

`BatchResolverInterface::resolve()` receives ALL requests at once:

```php
public function resolve(ContextInterface $context, Field $field, array $requests): BatchResponse
{
    // $requests = [ {value: {product_id: 1}}, {value: {product_id: 2}}, ... ]

    // 1. Collect all parent IDs
    $ids = array_map(fn ($r) => $r->getValue()['product_id'], $requests);

    // 2. Single batched fetch
    $criteria = $this->scb->addFilter('product_id', $ids, 'in')->create();
    $reviews = $this->repo->getList($criteria)->getItems();

    // 3. Group by parent
    $byProduct = [];
    foreach ($reviews as $r) {
        $byProduct[$r->getProductId()][] = ['id' => $r->getId(), 'text' => $r->getText()];
    }

    // 4. Build response keyed by request
    $response = new BatchResponse();
    foreach ($requests as $request) {
        $pid = $request->getValue()['product_id'];
        $response->addResponse($request, $byProduct[$pid] ?? []);
    }
    return $response;
}
```

Total queries: 1 batched fetch, regardless of N.

## When to Use Standard vs Batch

| Field context | Resolver type |
|---------------|---------------|
| Top-level query returning one entity | Standard |
| Top-level query returning a list | Standard (the list itself isn't N+1) |
| Field inside a list's items | Batch (without batch, N+1) |
| Mutation | Standard (mutations are usually one at a time) |
| Subscription | Standard |

## Naming Convention

Batch resolvers go under `Model/Resolver/Batch/`:

```
Model/Resolver/Get{Entity}.php             # Standard
Model/Resolver/Batch/{Entity}BatchResolver.php  # Batch
```

## DI Registration

Batch resolvers need an entry in the BatchResolverFactory list:

```xml
<type name="Magento\Framework\GraphQl\Query\Resolver\BatchResolverFactory">
    <arguments>
        <argument name="batchResolvers" xsi:type="array">
            <item name="reviews_for_product" xsi:type="string">{Vendor}\{Module}\Model\Resolver\Batch\ReviewsBatchResolver</item>
        </argument>
    </arguments>
</type>
```

The `name` is referenced from the schema:

```graphql
type Product {
    reviews: [Review] @resolver(class: "\\Magento\\Framework\\GraphQl\\Query\\Resolver\\BatchedResolver\\BatchedResolverProvider") @doc(batch: "reviews_for_product")
}
```

## DataLoader Alternative (Magento 2.4.5+)

Magento exposes a `Magento\GraphQl\Model\Resolver\DataLoaderInterface` pattern that
some teams prefer. The shape is similar to batch resolvers; pick one approach per
module and stick with it for consistency.

## Testing Batch Resolvers

Unit test:
- Call `resolve()` with 3 synthetic requests
- Assert exactly 1 call to the underlying repository
- Assert each request gets the correct items

If your test passes with N calls to the repository, the batch isn't working.

## Common Mistakes

- Batch resolver that loops over `$requests` and calls `repo->get()` per request — that's
  still N+1, just inside a batch interface.
- Forgetting to add the entry to `etc/graphql/di.xml` — the resolver is never invoked.
- Mismatched batch key between schema (`@doc(batch:`) and DI (`<item name=`).
