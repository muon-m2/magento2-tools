# GraphQL Auth Patterns

## Auth Sources in a Resolver

`ContextInterface` provides:

```php
$context->getExtensionAttributes()->getIsCustomer();      // bool
$context->getExtensionAttributes()->getCustomerId();      // int|null
$context->getExtensionAttributes()->getCustomerGroupId(); // int|null
$context->getUserId();                                    // int|null (admin)
$context->getUserType();                                  // int — 1=customer, 2=guest, 3=admin
```

## Three Auth Modes

### Anonymous

No restriction. Use only when the operation is intentionally public (e.g. category
listing, product detail by SKU).

Mutations should NEVER be anonymous without explicit justification. The skill asks for
the justification and includes it in the report.

### Customer-only

```php
if ($context->getExtensionAttributes()->getIsCustomer() === false) {
    throw new GraphQlAuthorizationException(__('Current customer does not have access'));
}
```

Equivalent: `getUserType() !== 1`. Use for any mutation modifying customer-owned data.

### Admin-only

```php
if ($context->getUserType() !== 3) {
    throw new GraphQlAuthorizationException(__('Admin authorization required'));
}
```

Use for back-office GraphQL endpoints.

## Schema Annotation (Magento 2.4.5+)

Modern Magento accepts `@doc(category="...")` annotations on schema fields to declare
auth requirements:

```graphql
mutation: {
    updateCart(...): Cart @doc(category="customer") @resolver(...)
}
```

Magento's framework checks the directive before invoking the resolver. Combine schema
directive + in-resolver check for defense in depth.

## Auth + Store Scope

Customer mutations must also verify the customer belongs to the active store:

```php
$customerId = (int) $context->getExtensionAttributes()->getCustomerId();
$customer = $this->customerRepository->getById($customerId);
$storeId = (int) $context->getExtensionAttributes()->getStore()->getId();
if (!in_array($storeId, $customer->getStores())) {
    throw new GraphQlAuthorizationException(__('Customer not authorized for this store'));
}
```

## Common Mistakes

| Mistake | Result |
|---------|--------|
| Checking `getCustomerId()` instead of `getIsCustomer()` | Guests with valid customer ID context (via stale token) pass |
| No check on schema directive AND in resolver | One change can accidentally remove auth |
| Returning data array even after auth fail | Data leak |
| Catching `GraphQlAuthorizationException` and returning empty | Leaks intent (some clients can distinguish "no data" from "no auth") |

## Error Type

Always throw the right type:
- `GraphQlAuthorizationException` — auth fail
- `GraphQlInputException` — bad input
- `GraphQlNoSuchEntityException` — not found
- `GraphQlAlreadyExistsException` — duplicate

GraphQL framework maps these to the right error codes in the response.
