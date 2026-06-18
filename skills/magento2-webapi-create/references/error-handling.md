# Error Handling — Exception → HTTP Status

The Web API maps framework exceptions to HTTP status codes automatically. Throw the *right*
exception and the client gets the right status with a clean, localized message. Throw a raw
`\Exception` and the client gets an opaque 500.

## Mapping table

| Throw | HTTP status | When |
|-------|-------------|------|
| `Magento\Framework\Exception\NoSuchEntityException` | **404** Not Found | `getById` / `deleteById` for a missing id |
| `Magento\Framework\Exception\CouldNotSaveException` | **400** Bad Request | `save` failed (validation, constraint, persistence) |
| `Magento\Framework\Exception\CouldNotDeleteException` | **400** Bad Request | `delete` failed |
| `Magento\Framework\Exception\InputException` | **400** Bad Request | Invalid argument (missing/typed-wrong input) |
| `Magento\Framework\Exception\LocalizedException` | **400** Bad Request | General domain error with a safe message |
| `Magento\Framework\Exception\AuthorizationException` | **401 / 403** | Caller lacks the ACL resource (usually enforced before your code) |
| `Magento\Framework\Exception\StateException` | **400** Bad Request | Operation invalid in the entity's current state (it extends `LocalizedException`) |
| uncaught `\Throwable` | **500** Internal Server Error | Bug — avoid; wrap in a framework exception |

`Webapi/ErrorProcessor` branches only on `NoSuchEntityException` (404) and
`AuthorizationException` / `AuthenticationException` (401); **every other `LocalizedException`
subclass — including `StateException`, `CouldNotSaveException`, `InputException` — returns 400.**
To return a different status (e.g. **409 Conflict**), throw `\Magento\Framework\Webapi\Exception`
directly with an explicit code: `throw new \Magento\Framework\Webapi\Exception(__('...'), 0,
\Magento\Framework\Webapi\Exception::HTTP_CONFLICT);`. Use that escape hatch sparingly — prefer the
typed framework exceptions above.

## Patterns

**Wrap low-level failures, preserve the cause:**

```php
try {
    $this->resource->save($entity);
} catch (\Throwable $e) {
    throw new CouldNotSaveException(__('Could not save the entity: %1', $e->getMessage()), $e);
}
```

Passing `$e` as the previous exception keeps the stack trace for logs while the client sees only the
localized message.

**Not-found is a 404, not an empty 200:**

```php
if ($entity->getEntityId() === null) {
    throw new NoSuchEntityException(__('No {entity} exists with ID %1.', $entityId));
}
```

## Message hygiene

- Always wrap user-facing text in `__()` so it is translatable.
- Never leak SQL, file paths, secrets, or stack frames into the exception message — that text is
  returned to the client. Put detail in the logged previous-exception, not the message.
- Keep messages actionable ("Name is required.") rather than internal ("constraint violation on
  uq_name").

## In developer vs production mode

In developer mode the API may include trace detail for a 500; in production it returns a generic
message. Do not rely on trace visibility — throw a typed exception so the *status* is correct
regardless of mode.
