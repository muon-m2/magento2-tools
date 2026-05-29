# Unit Test Patterns

## Common Skeleton

```php
<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\{SubNamespace};

use {Vendor}\{Module}\{SubNamespace}\{ClassUnderTest};
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

final class {ClassUnderTest}Test extends TestCase
{
    /** @var {Dep1FQCN}&MockObject */
    private MockObject $dep1;

    private {ClassUnderTest} $subject;

    protected function setUp(): void
    {
        $this->dep1 = $this->createMock(\{Dep1FQCN}::class);
        $this->subject = new {ClassUnderTest}($this->dep1);
    }

    public function testHappyPath(): void
    {
        // arrange
        $this->dep1->method('foo')->willReturn('bar');

        // act
        $result = $this->subject->execute();

        // assert
        self::assertSame('bar', $result);
    }

    public function testErrorPath(): void
    {
        $this->dep1->method('foo')->willThrowException(new \RuntimeException('boom'));

        $this->expectException(\RuntimeException::class);
        $this->subject->execute();
    }
}
```

## Per Source-Class Type

### Service

Test every public method. Mock dependencies. One happy + one error per method.

### Plugin

Test `before*` / `around*` / `after*` separately. Mock the target object; assert plugin
returns the expected modification.

### Observer

Mock `Magento\Framework\Event\Observer` and `Magento\Framework\Event`. Assert side effect
(via mocked collaborator) and that no exception escapes on missing event data.

### Controller

Mock `RequestInterface`, `ResponseInterface`, `ResultFactory`. Assert result type
(`Redirect`, `Json`, `Forward`, etc.) and that POST controllers reject GET (or vice versa).

### Cron job

Mock the collection or service the cron iterates. Assert at least one batch is processed.
Assert the cron logs and continues on per-item failure.

### Queue consumer

Mock the message processor. Assert decoded payload reaches the right service. Assert bad
messages route to dead-letter or are logged.

### GraphQL resolver

Mock `ContextInterface`, `Field`, value array. Assert: positive shape, auth fail
(`GraphQlAuthorizationException`), input error (`GraphQlInputException`).

### Repository

Mock `ResourceModel`, `Collection`, factories. Round-trip happy path: save, getById, getList,
delete. Assert exceptions on not-found.

### ViewModel / Block

Mock services. Assert return shape. For Blocks: assert `getIdentities()` returns expected
cache tags.

### Data patch / Schema patch

Mock `EavSetup` / `ModuleDataSetup`. Assert: patch applies, `getDependencies()` returns
expected, `getAliases()` returns `[]` or expected.

## Anti-Patterns

- **No assertion.** Every test method must contain at least one `self::assert*()` call.
- **Reflection to access privates.** If you need reflection, the source class is poorly
  designed — recommend refactor, don't paper over it.
- **Untyped mocks.** Always use `MockObject&Interface` typing.
- **Object Manager in tests.** Unit tests must construct the subject directly. Magento's
  `ObjectManagerHelper` is for integration tests only.
- **Shared mutable state between tests.** Re-initialise everything in `setUp()`.
