<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Api\Data;

use Magento\Framework\Api\SearchResultsInterface;

/**
 * {EntityName} search-results interface.
 *
 * Returned by {EntityName}RepositoryInterface::getList(). The getItems() override narrows
 * the return type so consumers get {EntityName}Interface[] without a runtime cast. Wire the
 * preference to \Magento\Framework\Api\SearchResults in di.xml.
 *
 * @api
 */
interface {EntityName}SearchResultsInterface extends SearchResultsInterface
{
    /**
     * Get the list of {entities}.
     *
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface[]
     */
    public function getItems(): array;

    /**
     * Set the list of {entities}.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface[] $items
     * @return $this
     */
    public function setItems(array $items): static;
}
