<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\Setup;

use Magento\Framework\App\ResourceConnection;
use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;

/**
 * @magentoDbIsolation enabled
 */
final class SchemaTest extends TestCase
{
    private ResourceConnection $resource;

    protected function setUp(): void
    {
        $this->resource = Bootstrap::getObjectManager()->get(ResourceConnection::class);
    }

    /**
     * @dataProvider tablesProvider
     */
    public function testTableExists(string $table): void
    {
        self::assertTrue(
            $this->resource->getConnection()->isTableExists($table),
            "Table {$table} declared in db_schema.xml should exist after setup:upgrade",
        );
    }

    public static function tablesProvider(): array
    {
        return [
            ['{vendor_lower}_{module_lower}_entity'],
            // Add one row per <table> in etc/db_schema.xml
        ];
    }
}
