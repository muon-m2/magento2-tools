<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model;

use Magento\Framework\Api\SearchCriteria\CollectionProcessorInterface;
use Magento\Framework\Api\SearchCriteriaInterface;
use Magento\Framework\Exception\CouldNotDeleteException;
use Magento\Framework\Exception\CouldNotSaveException;
use Magento\Framework\Exception\NoSuchEntityException;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}InterfaceFactory;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterfaceFactory;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName} as {EntityName}Resource;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * {EntityName} repository.
 *
 * Constructor argument order is the contract that Test/Unit/Model/{EntityName}RepositoryTest
 * mocks against — keep them in sync.
 */
class {EntityName}Repository implements {EntityName}RepositoryInterface
{
    /**
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName} $resource
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}InterfaceFactory $entityFactory
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterfaceFactory $searchResultsFactory
     * @param \Magento\Framework\Api\SearchCriteria\CollectionProcessorInterface $collectionProcessor
     */
    public function __construct(
        private readonly {EntityName}Resource $resource,
        private readonly {EntityName}InterfaceFactory $entityFactory,
        private readonly CollectionFactory $collectionFactory,
        private readonly {EntityName}SearchResultsInterfaceFactory $searchResultsFactory,
        private readonly CollectionProcessorInterface $collectionProcessor,
    ) {
    }

    /**
     * @inheritDoc
     */
    public function save({EntityName}Interface $entity): {EntityName}Interface
    {
        try {
            $this->resource->save($entity);
        } catch (\Throwable $e) {
            throw new CouldNotSaveException(__('Could not save the entity: %1', $e->getMessage()), $e);
        }
        return $entity;
    }

    /**
     * @inheritDoc
     */
    public function getById(int $entityId): {EntityName}Interface
    {
        $entity = $this->entityFactory->create();
        $this->resource->load($entity, $entityId);
        if ($entity->getEntityId() === null) {
            throw new NoSuchEntityException(__('No {entity} exists with ID %1.', $entityId));
        }
        return $entity;
    }

    /**
     * @inheritDoc
     */
    public function getList(SearchCriteriaInterface $searchCriteria): {EntityName}SearchResultsInterface
    {
        $collection = $this->collectionFactory->create();
        $this->collectionProcessor->process($searchCriteria, $collection);

        $searchResults = $this->searchResultsFactory->create();
        $searchResults->setSearchCriteria($searchCriteria);
        $searchResults->setItems($collection->getItems());
        $searchResults->setTotalCount($collection->getSize());
        return $searchResults;
    }

    /**
     * @inheritDoc
     */
    public function delete({EntityName}Interface $entity): bool
    {
        try {
            $this->resource->delete($entity);
        } catch (\Throwable $e) {
            throw new CouldNotDeleteException(__('Could not delete the entity: %1', $e->getMessage()), $e);
        }
        return true;
    }

    /**
     * @inheritDoc
     */
    public function deleteById(int $entityId): bool
    {
        return $this->delete($this->getById($entityId));
    }
}
