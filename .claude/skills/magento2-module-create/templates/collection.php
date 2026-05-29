<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName};

use Magento\Framework\Model\ResourceModel\Db\Collection\AbstractCollection;
use {Vendor}\{ModuleName}\Model\{EntityName} as {EntityName}Model;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName} as {EntityName}Resource;

/**
 * {EntityName} collection.
 */
class Collection extends AbstractCollection
{
    /**
     * @return void
     */
    protected function _construct(): void
    {
        $this->_init({EntityName}Model::class, {EntityName}Resource::class);
    }
}
