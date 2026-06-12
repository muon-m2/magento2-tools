<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Resolver;

use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Query\ResolverInterface;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class List{Entity} implements ResolverInterface
{
    private const MAX_PAGE_SIZE = 100;

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
     * Resolve a paginated list of {Entity} records.
     *
     * @param \Magento\Framework\GraphQl\Config\Element\Field $field
     * @param mixed $context
     * @param \Magento\Framework\GraphQl\Schema\Type\ResolveInfo $info
     * @param array|null $value
     * @param array|null $args
     * @return array
     */
    public function resolve(Field $field, $context, ResolveInfo $info, ?array $value = null, ?array $args = null)
    {
        $currentPage = (int) ($args['currentPage'] ?? 1);
        $pageSize = (int) ($args['pageSize'] ?? 20);

        if ($pageSize <= 0 || $pageSize > self::MAX_PAGE_SIZE) {
            throw new GraphQlInputException(
                __('pageSize must be between 1 and %1', self::MAX_PAGE_SIZE)
            );
        }
        if ($currentPage < 1) {
            throw new GraphQlInputException(__('currentPage must be ≥ 1'));
        }

        $criteria = $this->searchCriteriaBuilder
            ->setCurrentPage($currentPage)
            ->setPageSize($pageSize)
            ->create();

        $result = $this->repository->getList($criteria);

        $items = [];
        foreach ($result->getItems() as $entity) {
            $items[] = [
                'id' => $entity->getId(),
                'name' => $entity->getName(),
            ];
        }

        $totalCount = $result->getTotalCount();
        $totalPages = $totalCount > 0 ? (int) ceil($totalCount / $pageSize) : 0;

        return [
            'items' => $items,
            'total_count' => $totalCount,
            'page_info' => [
                'current_page' => $currentPage,
                'page_size' => $pageSize,
                'total_pages' => $totalPages,
            ],
        ];
    }
}
