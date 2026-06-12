<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Service\Importer;

use Magento\Framework\App\ResourceConnection;
use Psr\Log\LoggerInterface;

/**
 * Bulk importer for {entity} from a CSV source.
 *
 * Processes rows in chunks. Idempotent on unique_key.
 */
class {Entity}Importer
{
    private const CHUNK_SIZE = 500;
    private const UNIQUE_KEY = 'unique_key';

    /**
     * Constructor.
     *
     * @param \Magento\Framework\App\ResourceConnection $resource
     * @param \Psr\Log\LoggerInterface $logger
     */
    public function __construct(
        private readonly ResourceConnection $resource,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Import rows from the given CSV source file.
     *
     * @param string $sourcePath
     * @return array{processed: int, skipped: int, failed: int}
     */
    public function import(string $sourcePath): array
    {
        if (!is_file($sourcePath)) {
            throw new \InvalidArgumentException("Source not found: {$sourcePath}");
        }

        $stats = ['processed' => 0, 'skipped' => 0, 'failed' => 0];
        $handle = fopen($sourcePath, 'r');
        if ($handle === false) {
            throw new \RuntimeException("Cannot open source: {$sourcePath}");
        }
        $header = fgetcsv($handle);
        if ($header === false) {
            fclose($handle);
            throw new \InvalidArgumentException("Source has no header row: {$sourcePath}");
        }

        $chunk = [];
        $lineNo = 1; // header consumed above
        while (($row = fgetcsv($handle)) !== false) {
            $lineNo++;
            // A ragged row (column count != header count) makes array_combine() throw a
            // ValueError on PHP 8. That must count as ONE failed row, not abort the whole
            // import — the contract is "a failing row does NOT abort the run".
            if (count($row) !== count($header)) {
                $stats['failed']++;
                $this->logger->error('Import row failed: column count mismatch', [
                    'line'             => $lineNo,
                    'expected_columns' => count($header),
                    'actual_columns'   => count($row),
                ]);
                continue;
            }
            $chunk[] = array_combine($header, $row);
            if (count($chunk) >= self::CHUNK_SIZE) {
                $this->processChunk($chunk, $stats);
                $chunk = [];
            }
        }
        if ($chunk) {
            $this->processChunk($chunk, $stats);
        }
        fclose($handle);

        $this->logger->info('Importer finished', $stats);
        return $stats;
    }

    /**
     * Insert a chunk of rows, deduplicating by unique key and updating stats.
     *
     * @param array $rows Rows to insert; each an associative array of column => value.
     * @param array $stats Running totals updated in place: processed, skipped, failed.
     */
    private function processChunk(array $rows, array &$stats): void
    {
        $connection = $this->resource->getConnection();
        $table = $this->resource->getTableName('{vendor_lower}_{module_lower}_imported');

        foreach ($rows as $row) {
            try {
                $exists = $connection->fetchOne(
                    "SELECT entity_id FROM {$table} WHERE " . self::UNIQUE_KEY . " = ?",
                    [$row[self::UNIQUE_KEY]]
                );
                if ($exists) {
                    $stats['skipped']++;
                    continue;
                }
                $connection->insert($table, $row);
                $stats['processed']++;
            } catch (\Throwable $e) {
                $stats['failed']++;
                $this->logger->error('Import row failed', ['row' => $row, 'error' => $e->getMessage()]);
            }
        }
    }
}
