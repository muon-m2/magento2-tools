<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\Model;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\Exception\NoSuchEntityException;
use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Api\Data\{Entity}Interface;
use {Vendor}\{Module}\Api\Data\{Entity}InterfaceFactory;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

/**
 * @magentoDbIsolation enabled
 */
final class {Entity}RepositoryTest extends TestCase
{
    private {Entity}RepositoryInterface $repository;
    private {Entity}InterfaceFactory $factory;
    private SearchCriteriaBuilder $searchCriteriaBuilder;

    protected function setUp(): void
    {
        $om = Bootstrap::getObjectManager();
        $this->repository = $om->get({Entity}RepositoryInterface::class);
        $this->factory = $om->get({Entity}InterfaceFactory::class);
        $this->searchCriteriaBuilder = $om->get(SearchCriteriaBuilder::class);
    }

    public function testRoundTrip(): void
    {
        $entity = $this->factory->create();
        $entity->setName('integration-test');

        $saved = $this->repository->save($entity);
        self::assertNotNull($saved->getId());

        $loaded = $this->repository->getById($saved->getId());
        self::assertSame('integration-test', $loaded->getName());

        $list = $this->repository->getList($this->searchCriteriaBuilder->create());
        self::assertGreaterThan(0, $list->getTotalCount());

        $this->repository->delete($loaded);

        $this->expectException(NoSuchEntityException::class);
        $this->repository->getById($saved->getId());
    }
}
