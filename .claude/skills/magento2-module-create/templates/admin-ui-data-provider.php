<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Ui\DataProvider;

use Magento\Framework\Api\Filter;
use Magento\Framework\App\Request\DataPersistorInterface;
use Magento\Ui\DataProvider\AbstractDataProvider;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Collection;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Data provider for {EntityName} admin listing.
 */
class {EntityName}DataProvider extends AbstractDataProvider
{
    /**
     * @var mixed[]
     */
    private array $loadedData = [];

    /**
     * @param string $name
     * @param string $primaryFieldName
     * @param string $requestFieldName
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     * @param \Magento\Framework\App\Request\DataPersistorInterface $dataPersistor
     * @param mixed[] $meta
     * @param mixed[] $data
     */
    public function __construct(
        string $name,
        string $primaryFieldName,
        string $requestFieldName,
        CollectionFactory $collectionFactory,
        private readonly DataPersistorInterface $dataPersistor,
        array $meta = [],
        array $data = []
    ) {
        parent::__construct($name, $primaryFieldName, $requestFieldName, $meta, $data);
        $this->collection = $collectionFactory->create();
    }

    /**
     * Get loaded data keyed by entity_id.
     *
     * @return mixed[]
     */
    public function getData(): array
    {
        if (!empty($this->loadedData)) {
            return $this->loadedData;
        }

        /** @var Collection $collection */
        $collection = $this->getCollection();
        foreach ($collection->getItems() as $item) {
            $this->loadedData[(int) $item->getEntityId()] = $item->getData();
        }

        $persistedData = $this->dataPersistor->get('{vendor_lower}_{module_lower}_{entity}');
        if (is_array($persistedData) && $persistedData !== []) {
            $id = $persistedData['entity_id'] ?? 0;
            $this->loadedData[(int) $id] = $persistedData;
            $this->dataPersistor->clear('{vendor_lower}_{module_lower}_{entity}');
        }

        return $this->loadedData;
    }
}
