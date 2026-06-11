<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Resolver\Batch;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Query\Resolver\BatchResolverInterface;
use Magento\Framework\GraphQl\Query\Resolver\BatchResponse;
use Magento\Framework\GraphQl\Query\Resolver\ContextInterface;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;

/**
 * Batch resolver: avoid N+1 when {EntityName} is requested per item across a list query.
 *
 * For complex batch loading (auth, store scope, schema migration) the `magento2-graphql-create`
 * skill is the canonical source — its `templates/batch-resolver.php` is the reference copy.
 * This template covers the simple "resolve N by id in one query" case for module-create's
 * GraphQL surface.
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
     * Signature matches Magento\Framework\GraphQl\Query\Resolver\BatchResolverInterface:
     * resolve(ContextInterface $context, Field $field, array $requests): BatchResponse.
     *
     * @param \Magento\Framework\GraphQl\Query\Resolver\ContextInterface $context
     * @param \Magento\Framework\GraphQl\Config\Element\Field $field
     * @param \Magento\Framework\GraphQl\Query\Resolver\BatchRequestItemInterface[] $requests
     *
     * @return \Magento\Framework\GraphQl\Query\Resolver\BatchResponse
     */
    public function resolve(ContextInterface $context, Field $field, array $requests): BatchResponse
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
