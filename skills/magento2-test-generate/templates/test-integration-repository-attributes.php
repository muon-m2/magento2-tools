<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\Model;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\Exception\NoSuchEntityException;
use Magento\TestFramework\Fixture\AppArea;
use Magento\TestFramework\Fixture\DbIsolation;
use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Api\Data\{Entity}InterfaceFactory;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

/**
 * Attribute-first integration test (Magento 2.4.5+, PHPUnit 10+).
 *
 * Prefer this style over doc-comment annotations on modern Magento. For older
 * Magento (or PHPUnit 9) fall back to the @magento* annotation variant in
 * test-integration-repository.php.
 */
#[AppArea('adminhtml')]
#[DbIsolation(true)]
class {Entity}RepositoryTest extends TestCase
{
    /** @var {Entity}RepositoryInterface */
    private {Entity}RepositoryInterface $repository;

    /** @var {Entity}InterfaceFactory */
    private {Entity}InterfaceFactory $factory;

    /** @var SearchCriteriaBuilder */
    private SearchCriteriaBuilder $searchCriteriaBuilder;

    /**
     * Resolves the repository, factory and search criteria builder from the object manager.
     */
    protected function setUp(): void
    {
        $om = Bootstrap::getObjectManager();
        $this->repository = $om->get({Entity}RepositoryInterface::class);
        $this->factory = $om->get({Entity}InterfaceFactory::class);
        $this->searchCriteriaBuilder = $om->get(SearchCriteriaBuilder::class);
    }

    /**
     * Asserts a save/load/list/delete round trip through the repository.
     */
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
