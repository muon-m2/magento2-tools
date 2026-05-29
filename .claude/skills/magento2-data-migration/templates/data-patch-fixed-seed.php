<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Seed a fixed set of reference rows.
 *
 * Re-run safety: This patch is idempotent. Rows already present (matched by
 * `unique_key`) are skipped.
 */
final class Seed{Entity}Defaults implements DataPatchInterface
{
    private const ROWS = [
        ['code' => 'pending', 'label' => 'Pending', 'sort_order' => 10],
        ['code' => 'approved', 'label' => 'Approved', 'sort_order' => 20],
        ['code' => 'rejected', 'label' => 'Rejected', 'sort_order' => 30],
    ];

    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
    ) {
    }

    public function apply(): self
    {
        $connection = $this->moduleDataSetup->getConnection();
        $connection->startSetup();
        try {
            $table = $this->moduleDataSetup->getTable('{vendor_lower}_{module_lower}_status');
            foreach (self::ROWS as $row) {
                $exists = $connection->fetchOne(
                    "SELECT entity_id FROM {$table} WHERE code = ?",
                    [$row['code']]
                );
                if (!$exists) {
                    $connection->insert($table, $row);
                }
            }
        } finally {
            $connection->endSetup();
        }
        return $this;
    }

    /**
     * @return array<int, class-string>
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * @return array<int, string>
     */
    public function getAliases(): array
    {
        return [];
    }
}
