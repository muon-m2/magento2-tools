<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Resolver\Batch;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Query\Resolver\BatchRequestItemInterface;
use Magento\Framework\GraphQl\Query\Resolver\BatchResolverInterface;
use Magento\Framework\GraphQl\Query\Resolver\BatchResponse;
use Magento\Framework\GraphQl\Query\Resolver\ContextInterface;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class {Entity}BatchResolver implements BatchResolverInterface
{
    /**
     * Constructor.
     *
     * @param \{Vendor}\{Module}\Api\{Entity}RepositoryInterface $repository
     * @param \Magento\Framework\Api\SearchCriteriaBuilder $searchCriteriaBuilder
     */
    public function __construct(
        private readonly {Entity}RepositoryInterface $repository,
        private readonly SearchCriteriaBuilder $searchCriteriaBuilder,
    ) {
    }

    /**
     * Resolve a batch of {Entity} requests grouped by parent id.
     *
     * @param \Magento\Framework\GraphQl\Query\Resolver\ContextInterface $context
     * @param \Magento\Framework\GraphQl\Config\Element\Field $field
     * @param \Magento\Framework\GraphQl\Query\Resolver\BatchRequestItemInterface[] $requests
     * @return \Magento\Framework\GraphQl\Query\Resolver\BatchResponse
     */
    public function resolve(ContextInterface $context, Field $field, array $requests): BatchResponse
    {
        $parentIds = array_map(
            static fn (BatchRequestItemInterface $r) => (int) $r->getValue()['{parent_id_key}'],
            $requests
        );

        $criteria = $this->searchCriteriaBuilder
            ->addFilter('{parent_id_key}', $parentIds, 'in')
            ->create();
        $items = $this->repository->getList($criteria)->getItems();

        $byParent = [];
        foreach ($items as $item) {
            $byParent[$item->get{ParentIdAccessor}()][] = [
                'id' => $item->getId(),
                'name' => $item->getName(),
            ];
        }

        $response = new BatchResponse();
        foreach ($requests as $request) {
            $pid = (int) $request->getValue()['{parent_id_key}'];
            $response->addResponse($request, $byParent[$pid] ?? []);
        }

        return $response;
    }
}
