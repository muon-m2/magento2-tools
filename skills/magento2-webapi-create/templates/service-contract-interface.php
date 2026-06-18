<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Api;

/**
 * Service contract for persisting, retrieving, listing, and deleting {EntityName} entities.
 *
 * This is the @api contract the REST routes in etc/webapi.xml bind to. Keep it stable: once
 * published, removing or narrowing a method is a backward-incompatible change.
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
     * Get list of {entities} matching the given SearchCriteria.
     *
     * The SearchCriteria carries filters, sort orders, and pagination — the Web API builds it
     * from the request query string (searchCriteria[...]). See references/search-criteria.md.
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

    /**
     * EXAMPLE custom action — activate an {entity}.
     *
     * Custom (non-CRUD) actions are optional. Remove this method for a CRUD-only API, or rename
     * and adapt it to your domain. If you keep it, mirror it with a <route> in etc/webapi.xml
     * (e.g. POST /V1/{vendor_lower}/{route}/:entityId/activate) and an implementation in
     * {EntityName}Repository. Keep business logic in a domain service, not the repository.
     *
     * @param int $entityId
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface
     * @throws \Magento\Framework\Exception\NoSuchEntityException
     * @throws \Magento\Framework\Exception\CouldNotSaveException
     */
    public function activate(
        int $entityId
    ): \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
}
