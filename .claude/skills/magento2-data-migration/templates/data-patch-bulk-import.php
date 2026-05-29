<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Framework\Module\Dir\Reader;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use {Vendor}\{Module}\Service\Importer\{Entity}Importer;

/**
 * Bulk-import {entities} from a bundled source file.
 *
 * Source: etc/data/{file_name}.csv (alongside the module's etc folder).
 * Re-run safety: This patch is idempotent via the importer's per-row dedup.
 */
final class Import{Entity}Seed implements DataPatchInterface
{
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
        private readonly Reader $moduleReader,
        private readonly {Entity}Importer $importer,
    ) {
    }

    public function apply(): self
    {
        $connection = $this->moduleDataSetup->getConnection();
        $connection->startSetup();
        try {
            $sourceDir = $this->moduleReader->getModuleDir('etc', '{Vendor}_{Module}');
            $sourcePath = $sourceDir . '/data/{file_name}.csv';
            $this->importer->import($sourcePath);
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
