<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Transform {description}.
 *
 * Re-run safety: This patch is idempotent. It checks the destination state before
 * inserting, and the source rows remain until the destination is verified.
 */
final class Transform{From}To{To} implements DataPatchInterface
{
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
    ) {
    }

    public function apply(): self
    {
        $connection = $this->moduleDataSetup->getConnection();
        $connection->startSetup();
        $connection->beginTransaction();
        try {
            $sourceTable = $this->moduleDataSetup->getTable('{source_table}');
            $targetTable = $this->moduleDataSetup->getTable('{target_table}');

            // 1. Read source rows that haven't been migrated yet.
            $rows = $connection->fetchAll(
                "SELECT * FROM {$sourceTable} WHERE migrated_at IS NULL"
            );

            // 2. Write to destination with dedup on a stable key.
            foreach ($rows as $row) {
                $exists = $connection->fetchOne(
                    "SELECT id FROM {$targetTable} WHERE legacy_id = ?",
                    [$row['id']]
                );
                if ($exists) {
                    continue;
                }
                $connection->insert($targetTable, [
                    'legacy_id' => $row['id'],
                    'name' => $row['name'],
                    'created_at' => $row['created_at'],
                ]);
            }

            // 3. Mark source rows migrated (preserves them for rollback).
            $connection->update(
                $sourceTable,
                ['migrated_at' => date('Y-m-d H:i:s')],
                ['migrated_at IS NULL']
            );

            $connection->commit();
        } catch (\Throwable $e) {
            $connection->rollBack();
            throw $e;
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
