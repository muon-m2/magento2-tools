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
class Seed{Entity}Defaults implements DataPatchInterface
{
    private const ROWS = [
        ['code' => 'pending', 'label' => 'Pending', 'sort_order' => 10],
        ['code' => 'approved', 'label' => 'Approved', 'sort_order' => 20],
        ['code' => 'rejected', 'label' => 'Rejected', 'sort_order' => 30],
    ];

    /**
     * Constructor.
     *
     * @param \Magento\Framework\Setup\ModuleDataSetupInterface $moduleDataSetup
     */
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
    ) {
    }

    /**
     * Apply the data patch by seeding the fixed reference rows.
     *
     * @return self
     */
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
     * Get the patches this patch depends on.
     *
     * @return array<int, class-string>
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * Get the aliases for this patch.
     *
     * @return array<int, string>
     */
    public function getAliases(): array
    {
        return [];
    }
}
