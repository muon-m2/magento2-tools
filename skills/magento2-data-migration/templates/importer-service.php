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
final class {Entity}Importer
{
    private const CHUNK_SIZE = 500;
    private const UNIQUE_KEY = 'unique_key';

    public function __construct(
        private readonly ResourceConnection $resource,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
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
        while (($row = fgetcsv($handle)) !== false) {
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
     * @param array<int, array<string, mixed>> $rows
     * @param array{processed: int, skipped: int, failed: int} $stats
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
