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

## Wiring

A batch resolver is referenced directly from the schema with `@resolver(class: "...")`,
exactly like a standard resolver. There is no factory, provider, or batch-key registration:
Magento detects that the class implements `BatchResolverInterface` and dispatches all
requests for the field in a single `resolve()` call.

```graphql
type Product {
    reviews: [Review] @resolver(class: "\\{Vendor}\\{Module}\\Model\\Resolver\\Batch\\ReviewsBatchResolver")
}
```

No `di.xml` entry is needed for the resolver reference itself — add `di.xml` only if the
resolver's constructor dependencies need configuration.

For batch resolvers that delegate to a service contract / repository, Magento also ships
`Magento\Framework\GraphQl\Query\Resolver\BatchServiceContractResolverInterface` as a base.

## Testing Batch Resolvers

Unit test:
- Call `resolve()` with 3 synthetic requests
- Assert exactly 1 call to the underlying repository
- Assert each request gets the correct items

If your test passes with N calls to the repository, the batch isn't working.

## Common Mistakes

- Batch resolver that loops over `$requests` and calls `repo->get()` per request — that's
  still N+1, just inside a batch interface.
- Pointing the field's `@resolver(class: "...")` at a standard resolver instead of the
  `BatchResolverInterface` implementation — the field falls back to per-item resolution.
- Wrong FQCN in `@resolver` (typo or single backslash) — the resolver fails to load.
