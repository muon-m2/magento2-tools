<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Model\Resolver;

use Magento\Framework\Exception\NoSuchEntityException;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Exception\GraphQlNoSuchEntityException;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
use {Vendor}\{ModuleName}\Model\Resolver\{EntityName};

/**
 * Unit tests for the {EntityName} GraphQL resolver.
 */
class {EntityName}Test extends TestCase
{
    private {EntityName}RepositoryInterface&MockObject $repository;
    private {EntityName} $resolver;

    protected function setUp(): void
    {
        $this->repository = $this->createMock({EntityName}RepositoryInterface::class);
        $this->resolver   = new {EntityName}($this->repository);
    }

    public function testResolveReturnsEntityData(): void
    {
        $entity = $this->createMock({EntityName}Interface::class);
        $entity->method('getEntityId')->willReturn(42);
        $entity->method('getName')->willReturn('Test');
        $entity->method('getCreatedAt')->willReturn('2026-05-23 10:00:00');
        $entity->method('getUpdatedAt')->willReturn('2026-05-23 10:30:00');

        $this->repository->method('getById')->with(42)->willReturn($entity);

        $field   = $this->createMock(Field::class);
        $info    = $this->createMock(ResolveInfo::class);

        $result = $this->resolver->resolve($field, null, $info, null, ['id' => 42]);

        $this->assertSame(42, $result['id']);
        $this->assertSame('Test', $result['name']);
    }

    public function testResolveThrowsWhenIdMissing(): void
    {
        $this->expectException(GraphQlInputException::class);

        $field = $this->createMock(Field::class);
        $info  = $this->createMock(ResolveInfo::class);
        $this->resolver->resolve($field, null, $info, null, []);
    }

    public function testResolveThrowsWhenEntityNotFound(): void
    {
        $this->repository
            ->method('getById')
            ->willThrowException(new NoSuchEntityException());

        $this->expectException(GraphQlNoSuchEntityException::class);

        $field = $this->createMock(Field::class);
        $info  = $this->createMock(ResolveInfo::class);
        $this->resolver->resolve($field, null, $info, null, ['id' => 999]);
    }
}
