<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Resolver;

use Magento\Framework\Exception\NoSuchEntityException;
use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Exception\GraphQlNoSuchEntityException;
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
        } catch (NoSuchEntityException $e) {
            throw new GraphQlNoSuchEntityException(__($e->getMessage()), $e);
        }

        return [
            'id' => $entity->getId(),
            'name' => $entity->getName(),
        ];
    }
}
