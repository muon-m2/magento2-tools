<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Catalog\Model\Category;
use Magento\Eav\Model\Config;
use Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface;
use Magento\Eav\Setup\EavSetup;
use Magento\Eav\Setup\EavSetupFactory;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Add category EAV attribute `{attribute_code}`.
 */
class Add{AttributeCode}CategoryAttribute implements DataPatchInterface
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
            $existing = $this->eavConfig->getAttribute(Category::ENTITY, '{attribute_code}');
            if ($existing && $existing->getAttributeId()) {
                return $this;
            }

            /** @var EavSetup $eavSetup */
            $eavSetup = $this->eavSetupFactory->create(['setup' => $this->moduleDataSetup]);

            $eavSetup->addAttribute(
                Category::ENTITY,
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
                ]
            );
        } finally {
            $this->moduleDataSetup->getConnection()->endSetup();
        }

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
