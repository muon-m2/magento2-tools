<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\ViewModel;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\View\Element\Block\ArgumentInterface;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;

/**
 * {Name} view model.
 */
class {Name}ViewModel implements ArgumentInterface
{
    /**
     * @param \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository
     * @param \Magento\Framework\Api\SearchCriteriaBuilder $searchCriteriaBuilder
     */
    public function __construct(
        private readonly {EntityName}RepositoryInterface $repository,
        private readonly SearchCriteriaBuilder $searchCriteriaBuilder,
    ) {
    }

    /**
     * Get {entity} items for display.
     *
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface[]
     */
    public function getItems(): array
    {
        $searchCriteria = $this->searchCriteriaBuilder->create();
        return $this->repository->getList($searchCriteria)->getItems();
    }
}
