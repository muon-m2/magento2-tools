<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Api;

/**
 * {EntityName} repository interface.
 *
 * @api
 */
interface {EntityName}RepositoryInterface
{
    /**
     * Save {entity}.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface $entity
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface
     * @throws \Magento\Framework\Exception\CouldNotSaveException
     */
    public function save(
        \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface $entity
    ): \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;

    /**
     * Get {entity} by ID.
     *
     * @param int $entityId
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface
     * @throws \Magento\Framework\Exception\NoSuchEntityException
     */
    public function getById(int $entityId): \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;

    /**
     * Get list of {entities} matching the given criteria.
     *
     * @param \Magento\Framework\Api\SearchCriteriaInterface $searchCriteria
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterface
     */
    public function getList(
        \Magento\Framework\Api\SearchCriteriaInterface $searchCriteria
    ): \{Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterface;

    /**
     * Delete {entity}.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface $entity
     * @return bool
     * @throws \Magento\Framework\Exception\CouldNotDeleteException
     */
    public function delete(
        \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface $entity
    ): bool;

    /**
     * Delete {entity} by ID.
     *
     * @param int $entityId
     * @return bool
     * @throws \Magento\Framework\Exception\NoSuchEntityException
     * @throws \Magento\Framework\Exception\CouldNotDeleteException
     */
    public function deleteById(int $entityId): bool;
}
