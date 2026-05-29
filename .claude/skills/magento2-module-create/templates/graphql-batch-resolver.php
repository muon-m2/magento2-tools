<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Resolver\Batch;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Query\Resolver\BatchRequestItemInterface;
use Magento\Framework\GraphQl\Query\Resolver\BatchResolverInterface;
use Magento\Framework\GraphQl\Query\Resolver\BatchResponse;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;

/**
 * Batch resolver: avoid N+1 when {EntityName} is requested per item across a list query.
 */
class {EntityName}BatchResolver implements BatchResolverInterface
{
    /**
     * @param \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository
     * @param \Magento\Framework\Api\SearchCriteriaBuilder $criteriaBuilder
     */
    public function __construct(
        private readonly {EntityName}RepositoryInterface $repository,
        private readonly SearchCriteriaBuilder $criteriaBuilder,
    ) {
    }

    /**
     * Resolve all requested IDs in a single repository call.
     *
     * @param \Magento\Framework\GraphQl\Config\Element\Field $field
     * @param mixed $context
     * @param \Magento\Framework\GraphQl\Schema\Type\ResolveInfo $info
     * @param \Magento\Framework\GraphQl\Query\Resolver\BatchRequestItemInterface[] $requests
     * @return \Magento\Framework\GraphQl\Query\Resolver\BatchResponse
     */
    public function resolve(Field $field, $context, ResolveInfo $info, array $requests): BatchResponse
    {
        $ids = [];
        foreach ($requests as $request) {
            $args = $request->getArgs();
            if (isset($args['id'])) {
                $ids[] = (int) $args['id'];
            }
        }

        $byId = [];
        if ($ids !== []) {
            $criteria = $this->criteriaBuilder
                ->addFilter('entity_id', array_unique($ids), 'in')
                ->create();
            foreach ($this->repository->getList($criteria)->getItems() as $entity) {
                $byId[(int) $entity->getEntityId()] = [
                    'id' => (int) $entity->getEntityId(),
                    'name' => $entity->getName(),
                    'created_at' => $entity->getCreatedAt(),
                    'updated_at' => $entity->getUpdatedAt(),
                ];
            }
        }

        $response = new BatchResponse();
        foreach ($requests as $request) {
            $id = (int) ($request->getArgs()['id'] ?? 0);
            $response->addResponse($request, $byId[$id] ?? null);
        }

        return $response;
    }
}
