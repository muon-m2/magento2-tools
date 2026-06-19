<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Indexer;

use Magento\Framework\App\ResourceConnection;

/**
 * Reindex worker for the {Vendor}_{Module} custom indexer.
 *
 * Owns all batching, SQL, and idempotency logic. Called exclusively by {IndexerName} —
 * never invoked directly by Magento's indexer framework.
 *
 * Full reindex: truncates the target table, then re-populates it from the source in
 * paginated batches (idempotent — safe to run twice).
 * Partial reindex: processes the given id list in BATCH_SIZE chunks, deleting then
 * re-inserting each batch (idempotent — safe to re-run on the same id set).
 *
 * Target: {Vendor}/{Module}/Model/Indexer/{IndexerName}Action.php
 */
class {IndexerName}Action
{
    /**
     * Maximum number of entity ids processed per database round-trip.
     * Override via a DI preference when the default causes memory pressure.
     */
    private const BATCH_SIZE = 1000;

    /**
     * Source table: the table whose rows drive the index.
     * Subscribed in etc/mview.xml so changes schedule a partial reindex.
     */
    private const SOURCE_TABLE = '{source_table}';

    /**
     * Target index table: the materialized view written by this action.
     */
    private const TARGET_TABLE = '{target_table}';

    /**
     * Primary-key column used to match index rows to source entities.
     * Matches the entity_column of the mview subscription in etc/mview.xml.
     */
    private const ENTITY_COLUMN = '{id_column}';

    /**
     * @param \Magento\Framework\App\ResourceConnection $resource
     */
    public function __construct(
        private readonly ResourceConnection $resource
    ) {
    }

    /**
     * Full reindex — rebuild the entire index from scratch.
     *
     * Truncates the target table, then reads all source rows in batches and writes the
     * computed index rows. Running this method twice produces identical index state
     * (idempotent).
     */
    public function executeFull(): void
    {
        $connection = $this->resource->getConnection();
        $targetTable = $this->resource->getTableName(self::TARGET_TABLE);

        $connection->truncateTable($targetTable);

        // TODO: replace this keyset-paginated SELECT with real projection logic.
        // Read source rows in batches of BATCH_SIZE, compute derived columns, and
        // INSERT into $targetTable. Use a last-seen-id cursor for keyset pagination
        // instead of OFFSET/LIMIT to avoid full-scan drift on large tables.
        //
        // Example structure (adapt columns to your schema):
        //
        // $lastId = 0;
        // $sourceTable = $this->resource->getTableName(self::SOURCE_TABLE);
        // do {
        //     $select = $connection->select()
        //         ->from($sourceTable, ['entity_id', /* ...other cols... */])
        //         ->where('entity_id > ?', $lastId)
        //         ->order('entity_id ASC')
        //         ->limit(self::BATCH_SIZE);
        //     $rows = $connection->fetchAll($select);
        //     if (empty($rows)) {
        //         break;
        //     }
        //     $indexRows = $this->computeIndexRows($rows);
        //     $connection->insertMultiple($targetTable, $indexRows);
        //     $lastId = end($rows)['entity_id'];
        // } while (count($rows) === self::BATCH_SIZE);
    }

    /**
     * Partial reindex for a batch of entity ids.
     *
     * Deletes existing index rows for the given ids, then re-inserts computed rows.
     * This delete-then-insert pattern is idempotent — safe to call twice on the same
     * id set.
     *
     * Called by {IndexerName}::executeList(), {IndexerName}::executeRow(), and
     * {IndexerName}::execute() (Mview scheduled path). Large id sets are processed in
     * chunks of BATCH_SIZE to bound memory usage.
     *
     * @param array $ids Entity primary key values
     */
    public function execute(array $ids): void
    {
        if (empty($ids)) {
            return;
        }

        $connection = $this->resource->getConnection();
        $targetTable = $this->resource->getTableName(self::TARGET_TABLE);

        foreach (array_chunk($ids, self::BATCH_SIZE) as $batch) {
            // Delete stale index rows for this batch of ids.
            $connection->delete($targetTable, [self::ENTITY_COLUMN . ' IN (?)' => $batch]);

            // TODO: replace this stub with real projection logic.
            // SELECT source rows for $batch, compute derived columns, INSERT into
            // $targetTable. Example:
            //
            // $sourceTable = $this->resource->getTableName(self::SOURCE_TABLE);
            // $select = $connection->select()
            //     ->from($sourceTable, ['entity_id', /* ...other cols... */])
            //     ->where('entity_id IN (?)', $batch);
            // $rows = $connection->fetchAll($select);
            // if (!empty($rows)) {
            //     $indexRows = $this->computeIndexRows($rows);
            //     $connection->insertMultiple($targetTable, $indexRows);
            // }
        }
    }

    // TODO: add private computeIndexRows(array $sourceRows): array
    // that maps each source row to the corresponding index row structure.
}
