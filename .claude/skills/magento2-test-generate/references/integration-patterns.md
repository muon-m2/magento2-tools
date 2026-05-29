# Integration Test Patterns

Integration tests run against a real Magento install. They are slow and require a DB —
do not write them when a unit test suffices.

## Bootstrap

```php
use Magento\TestFramework\Helper\Bootstrap;

protected function setUp(): void
{
    $this->subject = Bootstrap::getObjectManager()->create(SomeClass::class);
}
```

## Fixtures

Use Magento's fixture annotations:

```php
/**
 * @magentoAppArea frontend
 * @magentoDataFixture {Vendor}_{Module}::Test/Integration/_files/customer.php
 * @magentoDataFixture {Vendor}_{Module}::Test/Integration/_files/product.php
 * @magentoDbIsolation enabled
 */
public function testRepositorySave(): void { ... }
```

`@magentoDbIsolation enabled` wraps the test in a DB transaction that's rolled back at
teardown. Use this for every integration test that mutates state.

## Fixture file format

```php
<?php
// _files/customer.php

use Magento\TestFramework\Helper\Bootstrap;
use Magento\Customer\Api\Data\CustomerInterface;
use Magento\Customer\Api\CustomerRepositoryInterface;

$objectManager = Bootstrap::getObjectManager();
$repo = $objectManager->get(CustomerRepositoryInterface::class);

$customer = $objectManager->create(CustomerInterface::class);
$customer->setEmail('test@example.com')->setFirstname('Test')->setLastname('User');
$repo->save($customer);
```

Sibling rollback file: `customer_rollback.php` — undoes the fixture. With
`@magentoDbIsolation enabled`, rollback is optional but recommended for safety.

## Schema Test

```php
public function testSchemaTablesExist(): void
{
    $connection = Bootstrap::getObjectManager()
        ->get(\Magento\Framework\App\ResourceConnection::class)
        ->getConnection();

    self::assertTrue($connection->isTableExists('{vendor_lower}_{module_lower}_entity'));
    self::assertTrue($connection->isTableExists('{vendor_lower}_{module_lower}_log'));
}
```

## Repository Round-Trip

```php
public function testRepositoryRoundTrip(): void
{
    $entity = $this->subject->create();
    $entity->setName('test');

    $saved = $this->subject->save($entity);
    self::assertNotNull($saved->getId());

    $loaded = $this->subject->getById($saved->getId());
    self::assertSame('test', $loaded->getName());

    $list = $this->subject->getList($this->searchCriteriaBuilder->create());
    self::assertGreaterThan(0, $list->getTotalCount());

    $this->subject->delete($loaded);
    $this->expectException(\Magento\Framework\Exception\NoSuchEntityException::class);
    $this->subject->getById($saved->getId());
}
```

## Data Patch Test

```php
public function testDataPatchApplies(): void
{
    $patch = Bootstrap::getObjectManager()->create(AddDefaultStatusesPatch::class);
    $patch->apply();

    // Assert the patch seeded the expected rows.
    $repo = Bootstrap::getObjectManager()->get(StatusRepositoryInterface::class);
    $list = $repo->getList(...);
    self::assertGreaterThanOrEqual(3, $list->getTotalCount());
}
```

## Running Integration Tests

```bash
{ctx.runner} vendor/bin/phpunit -c dev/tests/integration/phpunit.xml src/app/code/{Vendor}/{Module}/Test/Integration
```

The `phpunit.xml` for integration is at `dev/tests/integration/phpunit.xml` — different
config from `dev/tests/unit/phpunit.xml`. Use the right one.
