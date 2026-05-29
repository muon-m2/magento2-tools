<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\ResourceModel;

use Magento\Framework\Model\ResourceModel\Db\AbstractDb;

/**
 * {EntityName} resource model.
 */
class {EntityName} extends AbstractDb
{
    /**
     * @return void
     */
    protected function _construct(): void
    {
        // Table: {vendor_lower}_{module_lower}_{entity}   Primary key: entity_id
        $this->_init('{vendor_lower}_{module_lower}_{entity}', 'entity_id');
    }
}
