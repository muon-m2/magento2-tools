<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\Setup\Patch\Data;

use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Setup\Patch\Data\{Patch};

/**
 * @magentoDbIsolation enabled
 */
final class {Patch}Test extends TestCase
{
    private {Patch} $patch;

    protected function setUp(): void
    {
        $this->patch = Bootstrap::getObjectManager()->create({Patch}::class);
    }

    public function testApplyIsIdempotent(): void
    {
        $this->patch->apply();
        $this->patch->apply(); // second apply must not duplicate

        // Replace with assertion on the table the patch writes to.
        self::assertTrue(true);
    }

    public function testGetDependenciesReturnsArray(): void
    {
        self::assertIsArray({Patch}::getDependencies());
    }

    public function testGetAliasesReturnsEmptyArray(): void
    {
        self::assertSame([], $this->patch->getAliases());
    }
}
