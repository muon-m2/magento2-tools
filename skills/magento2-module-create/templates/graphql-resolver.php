<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Resolver;

use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Exception\GraphQlNoSuchEntityException;
use Magento\Framework\GraphQl\Query\ResolverInterface;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use Magento\Framework\Exception\NoSuchEntityException;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;

/**
 * GraphQL resolver: fetch a single {EntityName} by ID.
 */
class {EntityName} implements ResolverInterface
{
    /**
     * @param \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository
     */
    public function __construct(
        private readonly {EntityName}RepositoryInterface $repository,
    ) {
    }

    /**
     * Resolve the {EntityName} GraphQL field by loading the entity for the requested ID.
     *
     * @param \Magento\Framework\GraphQl\Config\Element\Field $field
     * @param mixed $context
     * @param \Magento\Framework\GraphQl\Schema\Type\ResolveInfo $info
     * @param mixed[]|null $value
     * @param mixed[]|null $args
     * @return mixed[]
     * @throws \Magento\Framework\GraphQl\Exception\GraphQlInputException
     * @throws \Magento\Framework\GraphQl\Exception\GraphQlNoSuchEntityException
     */
    public function resolve(Field $field, $context, ResolveInfo $info, ?array $value = null, ?array $args = null): array
    {
        if (empty($args['id'])) {
            throw new GraphQlInputException(__('Argument "id" is required.'));
        }

        try {
            $entity = $this->repository->getById((int) $args['id']);
        } catch (NoSuchEntityException $e) {
            throw new GraphQlNoSuchEntityException(__('No {entity} with ID %1.', [$args['id']]), $e);
        }

        return [
            'id' => (int) $entity->getEntityId(),
            'name' => $entity->getName(),
            'created_at' => $entity->getCreatedAt(),
            'updated_at' => $entity->getUpdatedAt(),
        ];
    }
}
