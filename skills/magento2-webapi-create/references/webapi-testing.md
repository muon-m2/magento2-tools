# Web API Testing

Web API endpoints are covered by **API-functional tests** — they call the real HTTP surface through
a test adapter, exercising routing, serialization, ACL, and the service method together. This is the
layer that proves the contract works end to end; unit tests on the repository (mocked deps) cover
the logic in isolation.

## WebapiAbstract

Extend `Magento\TestFramework\TestCase\WebapiAbstract`. The single entry point is `_webApiCall()`,
which dispatches against whichever adapter the suite is configured for (REST or SOAP) — so one test
covers both. Tests live under the module's `Test/Api/` and run from `dev/tests/api-functional`.

```php
$serviceInfo = [
    'rest' => [
        'resourcePath' => '/V1/{vendor_lower}/{route}',
        'httpMethod'   => Request::HTTP_METHOD_POST,
    ],
    'soap' => [
        'service'        => '{vendor_lower}{ModuleName}{EntityName}RepositoryV1',
        'serviceVersion' => 'V1',
        'operation'      => '{vendor_lower}{ModuleName}{EntityName}RepositoryV1Save',
    ],
];
$response = $this->_webApiCall($serviceInfo, ['entity' => ['name' => 'Test']]);
```

- **REST** identifies the operation by `resourcePath` + `httpMethod`.
- **SOAP** identifies it by `service` + `operation`. The service name is the interface's PHP class
  name with the `\Api\` namespace segment and the trailing `Interface` suffix removed, the remaining
  parts concatenated, and the **first character of the whole string lowercased**. For
  `{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface` this yields
  `{vendor_lower}{ModuleName}{EntityName}RepositoryV1`. The operation is that name + the method
  (`Save`, `GetById`, `GetList`, ...).

## What to assert

- **Round-trip:** create (`POST`) → read (`GET /:id`) → update (`PUT /:id`) → delete (`DELETE /:id`),
  asserting the response body and that ids line up. The repository template's test does the
  create→get→update→delete path.
- **getList envelope:** `items`, `search_criteria`, `total_count` keys present; filters/pagination honored.
- **Auth:** an unauthenticated or under-privileged call to a protected route is rejected — assert the
  expected status (the framework throws before your method runs).
- **Error mapping:** `GET /:id` for a missing id returns **404**; invalid `POST` payload returns **400**
  (see `error-handling.md`). `WebapiAbstract` exposes the response code via the thrown
  `\Exception` it raises on non-2xx, which you assert with `expectException` + the status check helper.

## Fixtures

Use `@magentoApiDataFixture` to seed and roll back data around a test, keeping each test isolated:

```php
/**
 * @magentoApiDataFixture Vendor/Module/_files/{entity}.php
 */
public function testGetById(): void { ... }
```

## Token-authenticated calls

For protected routes, `_webApiCall()` uses the suite's configured admin token by default. For
`self`-scoped routes, create a customer token and pass it in the request header per the
`WebapiAbstract` token helpers, so the test runs as that customer.

## Relationship to magento2-test-generate

`magento2-test-generate --types=api` can scaffold additional API-functional cases (more edge cases,
fixtures, negative auth). The template here is the round-trip baseline; generate from it outward.
