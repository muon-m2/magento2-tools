<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Setup\Patch\Data;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Data patch: {description}.
 *
 * Patches are idempotent — Magento tracks applied patches in `patch_list` and will not
 * re-apply this class. Do not implement self-skipping logic.
 */
class {PatchName} implements DataPatchInterface
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

        // Data mutation goes here. Use $this->moduleDataSetup->getConnection() for
        // safe parameterised queries, or inject domain repositories for higher-level
        // operations.

        $this->moduleDataSetup->getConnection()->endSetup();
        return $this;
    }

    /**
     * Other patches this patch depends on.
     *
     * @return string[]
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * Patch aliases (for renaming).
     *
     * @return string[]
     */
    public function getAliases(): array
    {
        return [];
    }
}
