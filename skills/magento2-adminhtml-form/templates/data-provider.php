<?php
/**
 * Adminhtml form data provider for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Model/{Entity}/DataProvider.php
 *
 * Feeds the {entity}_form UI component. getData() returns [ $id => [field => value] ] keyed by
 * the entity primary id (flat fields). DataPersistorInterface repopulates the New screen and a
 * failed save. For the modifier surface, extend ModifierPoolDataProvider instead and wire the
 * pool via di-modifier-pool.xml. See references/dataprovider-patterns.md.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Model\{Entity};

use {Vendor}\{Module}\Model\ResourceModel\{Entity}\CollectionFactory;
use Magento\Framework\App\Request\DataPersistorInterface;
use Magento\Ui\DataProvider\AbstractDataProvider;

class DataProvider extends AbstractDataProvider
{
    /**
     * @var array|null
     */
    private $loadedData;

    /**
     * @var DataPersistorInterface
     */
    private $dataPersistor;

    /**
     * @param string $name
     * @param string $primaryFieldName
     * @param string $requestFieldName
     * @param CollectionFactory $collectionFactory
     * @param DataPersistorInterface $dataPersistor
     * @param array $meta
     * @param array $data
     */
    public function __construct(
        $name,
        $primaryFieldName,
        $requestFieldName,
        CollectionFactory $collectionFactory,
        DataPersistorInterface $dataPersistor,
        array $meta = [],
        array $data = []
    ) {
        $this->collection = $collectionFactory->create();
        $this->dataPersistor = $dataPersistor;
        parent::__construct($name, $primaryFieldName, $requestFieldName, $meta, $data);
    }

    /**
     * Get form data keyed by entity id.
     *
     * @return array
     */
    public function getData(): array
    {
        if ($this->loadedData !== null) {
            return $this->loadedData;
        }

        $this->loadedData = [];
        foreach ($this->collection->getItems() as $model) {
            $this->loadedData[$model->getId()] = $model->getData();
        }

        $persisted = $this->dataPersistor->get('{vendor_lower}_{entity}');
        if (!empty($persisted)) {
            $model = $this->collection->getNewEmptyItem();
            $model->setData($persisted);
            $this->loadedData[$model->getId()] = $model->getData();
            $this->dataPersistor->clear('{vendor_lower}_{entity}');
        }

        return $this->loadedData;
    }
}
