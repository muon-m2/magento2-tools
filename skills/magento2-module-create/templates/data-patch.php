<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Setup\Patch\Data;

use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Data patch: {description}.
 *
 * Idempotency policy (single rule, with one exception):
 * - DEFAULT: Magento records applied patches in `patch_list` and never re-applies the same
 *   class, so a plain data patch does NOT need self-skipping logic — adding it is redundant.
 * - EXCEPTION — EAV attribute patches: `EavSetup::addAttribute()` is not safe to run twice
 *   (and may run again after a partial failure or a manually-created attribute), so those
 *   patches DO guard with `EavConfig::getAttribute()`. That is why the `magento2-eav-attribute`
 *   templates short-circuit while this generic patch does not — the two are consistent, not
 *   contradictory.
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
