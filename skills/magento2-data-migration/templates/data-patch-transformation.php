<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Transform {description}.
 *
 * Re-run safety: idempotent. Source rows are read in bounded primary-key chunks (keyset
 * pagination) so memory stays flat regardless of table size, the destination is checked
 * before each insert, and ONLY the ids actually processed in a chunk are marked migrated.
 */
class Transform{From}To{To} implements DataPatchInterface
{
    private const BATCH_SIZE = 500;

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
     * Apply the data patch by transforming source rows into the destination table.
     *
     * @return self
     */
    public function apply(): self
    {
        $connection = $this->moduleDataSetup->getConnection();
        $connection->startSetup();
        try {
            $sourceTable = $this->moduleDataSetup->getTable('{source_table}');
            $targetTable = $this->moduleDataSetup->getTable('{target_table}');

            $lastId = 0;
            // Keyset pagination by primary key: each pass reads at most BATCH_SIZE
            // not-yet-migrated rows with id > the last one seen. The old single
            // "SELECT * ... WHERE migrated_at IS NULL" loaded the entire table into memory
            // (violating the batch rule) and the blanket UPDATE below silently lost data.
            while (true) {
                $rows = $connection->fetchAll(
                    "SELECT * FROM {$sourceTable}
                      WHERE migrated_at IS NULL AND id > :lastId
                      ORDER BY id ASC
                      LIMIT " . self::BATCH_SIZE,
                    ['lastId' => $lastId],
                );
                if (!$rows) {
                    break;
                }

                $connection->beginTransaction();
                try {
                    $processedIds = [];
                    foreach ($rows as $row) {
                        $lastId = (int)$row['id'];

                        $exists = $connection->fetchOne(
                            "SELECT id FROM {$targetTable} WHERE legacy_id = ?",
                            [$row['id']],
                        );
                        if (!$exists) {
                            $connection->insert($targetTable, [
                                'legacy_id' => $row['id'],
                                'name' => $row['name'],
                                'created_at' => $row['created_at'],
                            ]);
                        }
                        // Record this id as done whether we inserted or it already existed.
                        $processedIds[] = (int)$row['id'];
                    }

                    // Mark ONLY the ids we processed this chunk. A blanket
                    // "WHERE migrated_at IS NULL" would also flag rows inserted by concurrent
                    // writers mid-run that were never copied — silent data loss.
                    if ($processedIds) {
                        $connection->update(
                            $sourceTable,
                            ['migrated_at' => date('Y-m-d H:i:s')],
                            ['id IN (?)' => $processedIds],
                        );
                    }

                    $connection->commit();
                } catch (\Throwable $e) {
                    $connection->rollBack();
                    throw $e;
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
