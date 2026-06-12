<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Catalog\Model\Product;
use Magento\Eav\Model\Config;
use Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface;
use Magento\Eav\Setup\EavSetup;
use Magento\Eav\Setup\EavSetupFactory;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Add product EAV attribute `{attribute_code}`.
 */
class Add{AttributeCode}Attribute implements DataPatchInterface
{
    /**
     * @param \Magento\Framework\Setup\ModuleDataSetupInterface $moduleDataSetup
     * @param \Magento\Eav\Setup\EavSetupFactory $eavSetupFactory
     * @param \Magento\Eav\Model\Config $eavConfig
     */
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
        private readonly EavSetupFactory $eavSetupFactory,
        private readonly Config $eavConfig,
    ) {
    }

    /**
     * Apply the patch. Idempotent: short-circuits if the attribute already exists.
     *
     * @return self
     */
    public function apply(): self
    {
        $this->moduleDataSetup->getConnection()->startSetup();

        try {
            $existing = $this->eavConfig->getAttribute(Product::ENTITY, '{attribute_code}');
            if ($existing && $existing->getAttributeId()) {
                return $this;
            }

            /** @var EavSetup $eavSetup */
            $eavSetup = $this->eavSetupFactory->create(['setup' => $this->moduleDataSetup]);

            $eavSetup->addAttribute(
                Product::ENTITY,
                '{attribute_code}',
                [
                'type'         => 'varchar',
                'label'        => '{Attribute Label}',
                'input'        => 'text',
                'required'     => false,
                'sort_order'   => 100,
                'global'       => ScopedAttributeInterface::SCOPE_STORE,
                'group'        => 'General',
                'visible'      => true,
                'user_defined' => true,
                'used_in_product_listing' => true,
                'is_used_in_grid'         => true,
                'is_visible_in_grid'      => false,
                'is_filterable_in_grid'   => true,
                // For select/multiselect inputs, set 'source' to a source-model class:
                // 'source' => \{Vendor}\{Module}\Model\Source\{AttributeCode}::class,
                // For non-trivial input types, set 'backend':
                // 'backend' => \{Vendor}\{Module}\Model\Attribute\Backend\{AttributeCode}::class,
                ]
            );
        } finally {
            $this->moduleDataSetup->getConnection()->endSetup();
        }

        return $this;
    }

    /**
     * Patches this patch depends on.
     *
     * @return string[]
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * Aliases for this patch.
     *
     * @return string[]
     */
    public function getAliases(): array
    {
        return [];
    }
}
