<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Ui\DataProvider;

use Magento\Ui\DataProvider\AbstractDataProvider;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Listing (grid) data provider for {EntityName}.
 *
 * Referenced as the dataSource in admin-ui-component-listing.xml. AbstractDataProvider::getData()
 * returns the GRID shape ($collection->toArray() => ['items' => [...], 'totalRecords' => N]),
 * which is what Magento_Ui/js/grid/provider expects — so getData() is intentionally NOT
 * overridden here. For the single-record edit form use {EntityName}FormDataProvider instead.
 */
class {EntityName}DataProvider extends AbstractDataProvider
{
    /**
     * @param string $name
     * @param string $primaryFieldName
     * @param string $requestFieldName
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     * @param mixed[] $meta
     * @param mixed[] $data
     */
    public function __construct(
        string $name,
        string $primaryFieldName,
        string $requestFieldName,
        CollectionFactory $collectionFactory,
        array $meta = [],
        array $data = []
    ) {
        parent::__construct($name, $primaryFieldName, $requestFieldName, $meta, $data);
        $this->collection = $collectionFactory->create();
    }
}
