<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Service;

/**
 * {Short description of what this service does}.
 *
 * Orchestration note: if this class exceeds 5 constructor dependencies,
 * add @SuppressWarnings(PHPMD.CouplingBetweenObjects) with an inline justification.
 */
class {ServiceName}Service
{
    /**
     * @param \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository
     */
    public function __construct(
        private readonly \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository,
    ) {
    }

    /**
     * {Describe what execute does — use concrete language, e.g. "Export order to the remote API."}.
     *
     * @param int $entityId
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface
     * @throws \Magento\Framework\Exception\NoSuchEntityException
     */
    public function execute(int $entityId): \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface
    {
        return $this->repository->getById($entityId);
    }
}
