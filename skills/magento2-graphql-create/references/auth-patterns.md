# GraphQL Auth Patterns

## Auth Sources in a Resolver

`ContextInterface` provides:

```php
$context->getExtensionAttributes()->getIsCustomer();      // bool
$context->getExtensionAttributes()->getCustomerId();      // int|null
$context->getExtensionAttributes()->getCustomerGroupId(); // int|null
$context->getUserId();                                    // int|null
$context->getUserType();                                  // int — see UserContextInterface
```

`getUserType()` returns one of the `Magento\Authorization\Model\UserContextInterface`
constants. **Always compare against the named constant, never a bare integer** — the
numeric values are NOT in "customer, guest, admin" order:

| Constant                                      | Value |
|-----------------------------------------------|-------|
| `UserContextInterface::USER_TYPE_INTEGRATION` | 1     |
| `UserContextInterface::USER_TYPE_ADMIN`       | 2     |
| `UserContextInterface::USER_TYPE_CUSTOMER`    | 3     |
| `UserContextInterface::USER_TYPE_GUEST`       | 4     |

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

Equivalent: `getUserType() !== UserContextInterface::USER_TYPE_CUSTOMER`. Use for any
mutation modifying customer-owned data.

### Admin-only

```php
use Magento\Authorization\Model\UserContextInterface;

if ((int) $context->getUserType() !== UserContextInterface::USER_TYPE_ADMIN) {
    throw new GraphQlAuthorizationException(__('Admin authorization required'));
}
```

Use for back-office GraphQL endpoints. Note `USER_TYPE_ADMIN` is **2**, not 3 — a bare
`!== 3` check rejects admins and admits customers, the exact inverse of the intent.

## Schema-level auth

Magento GraphQL has **no built-in schema directive that enforces authentication**. The
`@doc(...)` directive only carries documentation metadata; it does not gate access, and
the framework does not check it before invoking a resolver. Authentication and
authorization must be enforced **inside the resolver** (the checks above). Treat the
schema as public surface and the resolver as the trust boundary.

## Auth + Store Scope

A customer account belongs to a single website (not a list of stores). Verify the
customer's website matches the active store's website before serving customer-owned data:

```php
$customerId = (int) $context->getExtensionAttributes()->getCustomerId();
$customer = $this->customerRepository->getById($customerId);
$customerWebsiteId = (int) $customer->getWebsiteId();
$activeWebsiteId = (int) $context->getExtensionAttributes()->getStore()->getWebsiteId();
if ($customerWebsiteId !== $activeWebsiteId) {
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
