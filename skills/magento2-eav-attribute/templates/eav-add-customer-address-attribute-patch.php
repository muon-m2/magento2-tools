<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Setup\Patch\Data;

use Magento\Customer\Api\AddressMetadataInterface;
use Magento\Customer\Setup\CustomerSetupFactory;
use Magento\Eav\Model\Config;
use Magento\Eav\Model\Entity\Attribute\SetFactory as AttributeSetFactory;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;

/**
 * Add {AttributeCode} attribute to customer_address entity.
 */
class Add{AttributeCode}Attribute implements DataPatchInterface
{
    /**
     * Constructor.
     *
     * @param \Magento\Framework\Setup\ModuleDataSetupInterface $moduleDataSetup
     * @param \Magento\Customer\Setup\CustomerSetupFactory $customerSetupFactory
     * @param \Magento\Eav\Model\Entity\Attribute\SetFactory $attributeSetFactory
     * @param \Magento\Eav\Model\Config $eavConfig
     */
    public function __construct(
        private readonly ModuleDataSetupInterface $moduleDataSetup,
        private readonly CustomerSetupFactory $customerSetupFactory,
        private readonly AttributeSetFactory $attributeSetFactory,
        private readonly Config $eavConfig,
    ) {
    }

    /**
     * Apply the patch.
     */
    public function apply(): self
    {
        $this->moduleDataSetup->getConnection()->startSetup();

        try {
            $existing = $this->eavConfig->getAttribute('customer_address', '{attribute_code}');
            if ($existing && $existing->getAttributeId()) {
                return $this;
            }

            $customerSetup = $this->customerSetupFactory->create(['setup' => $this->moduleDataSetup]);
            $addressEntity = $customerSetup->getEavConfig()->getEntityType('customer_address');
            $attributeSetId = $addressEntity->getDefaultAttributeSetId();
            $attributeSet = $this->attributeSetFactory->create();
            $attributeGroupId = $attributeSet->getDefaultGroupId($attributeSetId);

            $customerSetup->addAttribute(
                'customer_address',
                '{attribute_code}',
                [
                    'type' => 'varchar',
                    'label' => '{Attribute Label}',
                    'input' => 'text',
                    'required' => false,
                    'visible' => true,
                    'user_defined' => true,
                    'sort_order' => 100,
                    'position' => 100,
                    'system' => 0,
                ]
            );

            $attribute = $customerSetup
                ->getEavConfig()
                ->getAttribute('customer_address', '{attribute_code}')
                ->addData([
                    'attribute_set_id' => $attributeSetId,
                    'attribute_group_id' => $attributeGroupId,
                    'used_in_forms' => [
                        'adminhtml_customer_address',
                        'customer_address_edit',
                        'customer_register_address',
                    ],
                ]);

            $attribute->save();
        } finally {
            $this->moduleDataSetup->getConnection()->endSetup();
        }

        return $this;
    }

    /**
     * Patches this depends on.
     *
     * @return array<int, class-string>
     */
    public static function getDependencies(): array
    {
        return [];
    }

    /**
     * Aliases.
     *
     * @return array<int, string>
     */
    public function getAliases(): array
    {
        return [];
    }
}
