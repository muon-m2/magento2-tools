# Resolver Patterns

## Standard Resolver

```php
<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Resolver;

use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Exception\GraphQlNoSuchEntityException;
use Magento\Framework\GraphQl\Query\Resolver\ContextInterface;
use Magento\Framework\GraphQl\Query\ResolverInterface;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

final class Get{Entity} implements ResolverInterface
{
    public function __construct(
        private readonly {Entity}RepositoryInterface $repository,
    ) {
    }

    public function resolve(Field $field, $context, ResolveInfo $info, ?array $value = null, ?array $args = null)
    {
        if (empty($args['id'])) {
            throw new GraphQlInputException(__('"id" is required'));
        }
        try {
            $entity = $this->repository->getById((int) $args['id']);
        } catch (\Magento\Framework\Exception\NoSuchEntityException $e) {
            throw new GraphQlNoSuchEntityException(__($e->getMessage()), $e);
        }

        return [
            'id' => $entity->getId(),
            'name' => $entity->getName(),
        ];
    }
}
```

## Batch Resolver

For list contexts that would otherwise N+1:

```php
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

final class {Entity}BatchResolver implements BatchResolverInterface
{
    public function __construct(
        private readonly {Entity}RepositoryInterface $repository,
        private readonly SearchCriteriaBuilder $searchCriteriaBuilder,
    ) {
    }

    public function resolve(ContextInterface $context, Field $field, array $requests): BatchResponse
    {
        $ids = array_map(static fn (BatchRequestItemInterface $r) => $r->getValue()['parent_id'], $requests);

        $criteria = $this->searchCriteriaBuilder
            ->addFilter('parent_id', $ids, 'in')
            ->create();
        $entities = $this->repository->getList($criteria)->getItems();

        $byParent = [];
        foreach ($entities as $entity) {
            $byParent[$entity->getParentId()][] = [
                'id' => $entity->getId(),
                'name' => $entity->getName(),
            ];
        }

        $response = new BatchResponse();
        foreach ($requests as $request) {
            $parentId = $request->getValue()['parent_id'];
            $response->addResponse($request, $byParent[$parentId] ?? []);
        }
        return $response;
    }
}
```

## Paginated Resolver

```php
public function resolve(Field $field, $context, ResolveInfo $info, ?array $value = null, ?array $args = null)
{
    $currentPage = (int) ($args['currentPage'] ?? 1);
    $pageSize = min((int) ($args['pageSize'] ?? 20), 100);  // cap at 100

    $criteria = $this->searchCriteriaBuilder
        ->setCurrentPage($currentPage)
        ->setPageSize($pageSize)
        ->create();
    $result = $this->repository->getList($criteria);

    return [
        'items' => array_map(fn ($i) => ['id' => $i->getId(), 'name' => $i->getName()], $result->getItems()),
        'total_count' => $result->getTotalCount(),
        'page_info' => [
            'current_page' => $currentPage,
            'page_size' => $pageSize,
            'total_pages' => (int) ceil($result->getTotalCount() / $pageSize),
        ],
    ];
}
```

## Mutation Resolver

```php
public function resolve(Field $field, $context, ResolveInfo $info, ?array $value = null, ?array $args = null)
{
    // 1. Auth check
    if ($context->getExtensionAttributes()->getIsCustomer() === false) {
        throw new GraphQlAuthorizationException(__('Current customer does not have access'));
    }

    // 2. Input validation
    if (empty($args['input']['name'])) {
        throw new GraphQlInputException(__('"name" is required'));
    }

    // 3. Mutation
    $entity = $this->factory->create();
    $entity->setName($args['input']['name']);
    $saved = $this->repository->save($entity);

    return ['id' => $saved->getId(), 'name' => $saved->getName()];
}
```

## Wiring a Batch Resolver

A class implementing `BatchResolverInterface` is wired the same way as a standard
resolver: reference it directly from the schema with the `@resolver(class: "...")`
directive on the field. There is no factory or provider to register, and no `di.xml`
entry is required for the resolver reference itself — Magento detects that the class
implements `BatchResolverInterface` and dispatches all requests for that field in one
call.

```graphql
type Product {
    reviews: [Review] @resolver(class: "\\{Vendor}\\{Module}\\Model\\Resolver\\Batch\\ReviewsBatchResolver")
}
```

Add `di.xml` only if the resolver's own constructor dependencies need configuration
(virtual types, argument overrides) — the same as for any other class.

> For service-contract-backed batch loading, Magento also ships
> `Magento\Framework\GraphQl\Query\Resolver\BatchServiceContractResolverInterface`,
> a base for batch resolvers that delegate to a repository/service contract.
