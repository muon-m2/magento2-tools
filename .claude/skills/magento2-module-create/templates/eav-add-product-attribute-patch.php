<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Setup\Patch\Data;

use Magento\Catalog\Model\Product;
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
     */
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
        private readonly EavSetupFactory $eavSetupFactory,
    ) {
    }

    /**
     * Apply the patch.
     *
     * @return self
     */
    public function apply(): self
    {
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
                // 'source' => \{Vendor}\{ModuleName}\Model\Source\{AttributeCode}::class,
                // For non-trivial input types, set 'backend':
                // 'backend' => \{Vendor}\{ModuleName}\Model\Attribute\Backend\{AttributeCode}::class,
            ]
        );

        return $this;
    }

    /**
     * @return string[]
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * @return string[]
     */
    public function getAliases(): array
    {
        return [];
    }
}
