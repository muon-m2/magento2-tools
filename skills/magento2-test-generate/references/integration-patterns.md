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

### Attribute-first (Magento 2.4.5+, PHPUnit 10+) — preferred

Magento 2.4.5 introduced PHP-attribute equivalents of the legacy fixture annotations.
On Magento 2.4.5 and newer, prefer attributes — they are type-checked, refactor-safe,
and required once you move to PHPUnit 10+ where doc-comment metadata is deprecated:

```php
use Magento\TestFramework\Fixture\DataFixture;
use Magento\TestFramework\Fixture\DbIsolation;
use Magento\TestFramework\Fixture\AppArea;
use Magento\Customer\Test\Fixture\Customer;
use Magento\Catalog\Test\Fixture\Product;

#[
    AppArea('frontend'),
    DbIsolation(true),
    DataFixture(Customer::class, as: 'customer'),
    DataFixture(Product::class, ['price' => 10], as: 'product'),
]
public function testRepositorySave(): void
{
    // Resolve created fixtures by their `as` alias:
    $customer = $this->fixtures->get('customer');
    $product = $this->fixtures->get('product');
    // ...
}
```

Inject the fixture registry in `setUp()`:

```php
use Magento\TestFramework\Fixture\DataFixtureStorageManager;
use Magento\TestFramework\Fixture\DataFixtureStorage;

private DataFixtureStorage $fixtures;

protected function setUp(): void
{
    $om = Bootstrap::getObjectManager();
    $this->fixtures = $om->get(DataFixtureStorageManager::class)->getStorage();
    // ... other dependencies
}
```

`#[DataFixture]` references a fixture **class** (implementing
`Magento\TestFramework\Fixture\DataFixtureInterface`) rather than a `_files/*.php`
script. Magento ships many ready-made fixtures (`Customer`, `Product`, `Category`,
`Order`, ...) under each module's `Test/Fixture/` namespace.

### Legacy annotations (Magento < 2.4.5 fallback)

Older Magento (or PHPUnit 9) does not support the attributes above. Use the
doc-comment annotations instead — still supported in 2.4.x but slated for removal:

```php
/**
 * @magentoAppArea frontend
 * @magentoDataFixture {Vendor}_{Module}::Test/Integration/_files/customer.php
 * @magentoDataFixture {Vendor}_{Module}::Test/Integration/_files/product.php
 * @magentoDbIsolation enabled
 */
public function testRepositorySave(): void { ... }
```

Pick one style per file — do not mix attributes and annotations on the same method.
`@magentoDbIsolation enabled` / `#[DbIsolation(true)]` wraps the test in a DB
transaction that's rolled back at teardown. Use it for every integration test that
mutates state.

### Data providers

`@dataProvider` is deprecated in PHPUnit 10+. On Magento 2.4.5+ use the
`#[DataProvider]` attribute (and `#[TestWith]` for inline cases):

```php
use PHPUnit\Framework\Attributes\DataProvider;

#[DataProvider('nameCasesProvider')]
public function testNormalisesName(string $input, string $expected): void { ... }

public static function nameCasesProvider(): array
{
    return [['  a ', 'a'], ['B', 'B']];
}
```

Note the provider method must be `public static` under PHPUnit 10+.

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
{ctx.runner} vendor/bin/phpunit -c dev/tests/integration/phpunit.xml {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration
```

The `phpunit.xml` for integration is at `dev/tests/integration/phpunit.xml` — different
config from `dev/tests/unit/phpunit.xml`. Use the right one.
