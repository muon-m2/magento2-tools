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

## DI Wiring

```xml
<!-- etc/graphql/di.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:ObjectManager/etc/config.xsd">
    <type name="Magento\Framework\GraphQl\Query\Resolver\BatchResolverFactory">
        <arguments>
            <argument name="batchResolvers" xsi:type="array">
                <item name="reviews_for_product" xsi:type="string">{Vendor}\{Module}\Model\Resolver\Batch\ReviewsBatchResolver</item>
            </argument>
        </arguments>
    </type>
</config>
```
