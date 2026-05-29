<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Service;

use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
use {Vendor}\{ModuleName}\Service\{ServiceName}Service;
use Magento\Framework\Exception\NoSuchEntityException;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

/**
 * Unit tests for {ServiceName}Service.
 */
class {ServiceName}ServiceTest extends TestCase
{
    private {EntityName}RepositoryInterface&MockObject $repository;
    private {ServiceName}Service $subject;

    protected function setUp(): void
    {
        $this->repository = $this->createMock({EntityName}RepositoryInterface::class);
        $this->subject    = new {ServiceName}Service($this->repository);
    }

    public function testExecuteReturnsEntity(): void
    {
        $entityId = 42;
        $entity   = $this->createMock({EntityName}Interface::class);

        $this->repository
            ->expects($this->once())
            ->method('getById')
            ->with($entityId)
            ->willReturn($entity);

        $result = $this->subject->execute($entityId);

        $this->assertSame($entity, $result);
    }

    public function testExecuteThrowsWhenEntityNotFound(): void
    {
        $this->expectException(NoSuchEntityException::class);

        $this->repository
            ->method('getById')
            ->willThrowException(new NoSuchEntityException());

        $this->subject->execute(999);
    }

    // Add test methods for each business-logic path in {ServiceName}Service.
    // Name each method: testVerb[Condition][ExpectedOutcome]
    // Examples:
    //   testSaveThrowsCouldNotSaveExceptionWhenRepositoryFails
    //   testGetListReturnsPaginatedResults
    //   testDeleteRemovesEntityFromStorage
}
