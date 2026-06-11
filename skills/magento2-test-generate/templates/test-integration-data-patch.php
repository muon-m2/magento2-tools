<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\Setup\Patch\Data;

use Magento\Framework\App\ResourceConnection;
use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Setup\Patch\Data\{Patch};

/**
 * @magentoDbIsolation enabled
 */
final class {Patch}Test extends TestCase
{
    // Replace with the table the patch writes to (use the raw table name, not the alias).
    private
    const SEEDED_TABLE = '{vendor_lower}_{module_lower}_entity';

    private {Patch} $patch;
    private
    ResourceConnection $resource;

    protected function setUp(): void
    {
        $om = Bootstrap::getObjectManager();
        $this->patch = $om->create({Patch}::class);
        $this->resource = $om->get(ResourceConnection::class);
    }

    public function testApplyIsIdempotent(): void
    {
        // First apply seeds the data.
        $this->patch->apply();
        $countAfterFirst = $this->countSeededRows();
        self::assertGreaterThan(
            0,
            $countAfterFirst,
            'Patch must seed at least one row on first apply.',
        );

        // Second apply must be a no-op — re-running the patch must not duplicate rows.
        $this->patch->apply();
        $countAfterSecond = $this->countSeededRows();

        self::assertSame(
            $countAfterFirst,
            $countAfterSecond,
            'Re-applying the patch duplicated rows; apply() is not idempotent.',
        );
    }

    public function testGetDependenciesReturnsArray(): void
    {
        self::assertIsArray({Patch}::getDependencies());
    }

    public function testGetAliasesReturnsArray(): void
    {
        // getAliases() may legitimately be non-empty when a patch supersedes an
        // older class name — assert the contract (an array), not that it is empty.
        self::assertIsArray($this->patch->getAliases());
    }

    private function countSeededRows(): int
{
    $connection = $this->resource->getConnection();
    $table = $this->resource->getTableName(self::SEEDED_TABLE);
    $select = $connection->select()->from($table, ['cnt' => 'COUNT(*)']);

    return (int)$connection->fetchOne($select);
    }
}
