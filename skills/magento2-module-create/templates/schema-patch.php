<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Setup\Patch\Schema;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\SchemaPatchInterface;

/**
 * Schema patch: {description}.
 *
 * Schema patches are for schema changes that declarative schema (etc/db_schema.xml)
 * cannot express — for example, custom indexes, complex constraints, or backfill of
 * a new column from an existing one. Prefer declarative schema where possible.
 */
class {PatchName} implements SchemaPatchInterface
{
    /**
     * @param \Magento\Framework\Setup\ModuleDataSetupInterface $moduleDataSetup
     */
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
    ) {
    }

    /**
     * Apply the patch.
     *
     * @return self
     */
    public function apply(): self
    {
        $this->moduleDataSetup->getConnection()->startSetup();

        // Schema mutation goes here. Always use the connection's DDL helpers
        // (addColumn, addIndex, addForeignKey) rather than raw SQL where possible.

        $this->moduleDataSetup->getConnection()->endSetup();
        return $this;
    }

    /**
     * Return the patch class names that must run before this one.
     *
     * @return string[]
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * Return the former class names this patch has been known by.
     *
     * @return string[]
     */
    public function getAliases(): array
    {
        return [];
    }
}
