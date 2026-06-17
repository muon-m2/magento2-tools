<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid;

use Magento\Framework\View\Element\UiComponent\DataProvider\SearchResult;

/**
 * Grid collection for the {EntityName} listing (SearchResult-based; supports joins).
 */
class Collection extends SearchResult
{
    /**
     * @return void
     */
    protected function _initSelect(): void
    {
        parent::_initSelect();
        // Add joins here, e.g. $this->getSelect()->join(...);
    }
}
