# API Test Patterns

## REST

Base class: `Magento\TestFramework\TestCase\WebapiAbstract`.

```php
namespace {Vendor}\{Module}\Test\Api;

use Magento\TestFramework\TestCase\WebapiAbstract;

class {Name}ApiTest extends WebapiAbstract
{
    private const RESOURCE_PATH = '/V1/{vendor_lower}/{route}';
    private const SERVICE_NAME = '{vendor}{Module}{Entity}RepositoryV1';

    public function testGetByIdReturns200(): void
    {
        $id = 1;
        $info = [
            'rest' => ['resourcePath' => self::RESOURCE_PATH . '/' . $id, 'httpMethod' => 'GET'],
            'soap' => ['service' => self::SERVICE_NAME, 'operation' => self::SERVICE_NAME . 'GetById'],
        ];

        $response = $this->_webApiCall($info, ['id' => $id]);

        self::assertArrayHasKey('id', $response);
        self::assertSame($id, $response['id']);
    }

    public function testGetByIdNotFoundReturns404(): void
    {
        $info = [
            'rest' => ['resourcePath' => self::RESOURCE_PATH . '/999999', 'httpMethod' => 'GET'],
            'soap' => ['service' => self::SERVICE_NAME, 'operation' => self::SERVICE_NAME . 'GetById'],
        ];

        try {
            $this->_webApiCall($info, ['id' => 999999]);
            self::fail('Expected NoSuchEntityException');
        } catch (\Exception $e) {
            self::assertStringContainsString('not found', strtolower($e->getMessage()));
        }
    }
}
```

Per route, generate:
- `test{Method}Returns{Code}` for the happy path
- `test{Method}NotFoundReturns404` for missing-resource
- `test{Method}UnauthorizedReturns401` for missing-token (if route is not anonymous)
- `test{Method}BadRequestReturns400` for invalid payload

## GraphQL

Base class: `Magento\TestFramework\TestCase\GraphQlAbstract`.

```php
namespace {Vendor}\{Module}\Test\Api\GraphQl;

use Magento\TestFramework\TestCase\GraphQlAbstract;

class {Name}QueryTest extends GraphQlAbstract
{
    public function testQueryReturnsShape(): void
    {
        $query = <<<QUERY
query {
    {vendor_lower}{Entity}(id: 1) {
        id
        name
        status
    }
}
QUERY;

        $response = $this->graphQlQuery($query);

        self::assertArrayHasKey('{vendor_lower}{Entity}', $response);
        self::assertSame(1, $response['{vendor_lower}{Entity}']['id']);
    }

    public function testMutationRequiresCustomerAuth(): void
    {
        $mutation = <<<MUTATION
mutation {
    update{Vendor}{Entity}(input: {id: 1, name: "x"}) {
        id
    }
}
MUTATION;

        // graphQlMutation wraps server errors in a generic \Exception; pin the
        // assertion to the specific authorization message rather than any \Exception.
        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('The current customer isn\'t authorized.');
        $this->graphQlMutation($mutation);
    }
}
```

Per operation, generate:
- `test{Op}ReturnsShape` for positive case
- `test{Op}AuthFails` for missing customer (mutations)
- `test{Op}InputErrorReturns{X}` for bad inputs

## Auth Header Helper (GraphQL with customer auth)

```php
$customerToken = $this->getCustomerToken('test@example.com', 'Password123');
$response = $this->graphQlMutation($mutation, [], '', ['Authorization' => 'Bearer ' . $customerToken]);
```

The base class includes a `getCustomerToken()` helper; reuse it.

## Running API Tests

```bash
{ctx.runner} vendor/bin/phpunit -c dev/tests/api-functional/phpunit_rest.xml \
    {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Api

{ctx.runner} vendor/bin/phpunit -c dev/tests/api-functional/phpunit_graphql.xml \
    {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Api/GraphQl
```
