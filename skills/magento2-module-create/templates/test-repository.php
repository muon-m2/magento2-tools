<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Model;

use Magento\Framework\Api\SearchCriteriaInterface;
use Magento\Framework\Exception\NoSuchEntityException;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}InterfaceFactory;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}SearchResultsInterfaceFactory;
use {Vendor}\{ModuleName}\Model\{EntityName} as {EntityName}Model;
use {Vendor}\{ModuleName}\Model\{EntityName}Repository;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName} as {EntityName}Resource;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Collection;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Unit tests for {EntityName}Repository.
 */
class {EntityName}RepositoryTest extends TestCase
{
    private {EntityName}Resource&MockObject $resource;
    private {EntityName}InterfaceFactory&MockObject $entityFactory;
    private CollectionFactory&MockObject $collectionFactory;
    private {EntityName}SearchResultsInterfaceFactory&MockObject $searchResultsFactory;
    private {EntityName}Repository $subject;

    protected function setUp(): void
    {
        $this->resource              = $this->createMock({EntityName}Resource::class);
        $this->entityFactory         = $this->createMock({EntityName}InterfaceFactory::class);
        $this->collectionFactory     = $this->createMock(CollectionFactory::class);
        $this->searchResultsFactory  = $this->createMock({EntityName}SearchResultsInterfaceFactory::class);

        $this->subject = new {EntityName}Repository(
            $this->resource,
            $this->entityFactory,
            $this->collectionFactory,
            $this->searchResultsFactory,
        );
    }

    public function testGetByIdReturnsEntity(): void
    {
        $entity = $this->createMock({EntityName}Model::class);
        $entity->method('getEntityId')->willReturn(42);

        $this->entityFactory->method('create')->willReturn($entity);
        $this->resource->expects($this->once())->method('load')->with($entity, 42);

        $result = $this->subject->getById(42);
        $this->assertSame($entity, $result);
    }

    public function testGetByIdThrowsWhenEntityNotFound(): void
    {
        $entity = $this->createMock({EntityName}Model::class);
        $entity->method('getEntityId')->willReturn(null);

        $this->entityFactory->method('create')->willReturn($entity);
        $this->resource->method('load');

        $this->expectException(NoSuchEntityException::class);
        $this->subject->getById(999);
    }

    public function testGetListReturnsSearchResults(): void
    {
        $criteria = $this->createMock(SearchCriteriaInterface::class);
        $collection = $this->createMock(Collection::class);
        $collection->method('getItems')->willReturn([]);
        $collection->method('getSize')->willReturn(0);

        $this->collectionFactory->method('create')->willReturn($collection);

        $searchResults = $this->createMock({EntityName}SearchResultsInterface::class);
        $searchResults->expects($this->once())->method('setItems')->with([]);
        $searchResults->expects($this->once())->method('setTotalCount')->with(0);

        $this->searchResultsFactory->method('create')->willReturn($searchResults);

        $result = $this->subject->getList($criteria);
        $this->assertSame($searchResults, $result);
    }
}
