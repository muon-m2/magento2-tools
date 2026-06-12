<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Resolver;

use Magento\Framework\GraphQl\Config\Element\Field;
use Magento\Framework\GraphQl\Exception\GraphQlAuthorizationException;
use Magento\Framework\GraphQl\Exception\GraphQlInputException;
use Magento\Framework\GraphQl\Query\ResolverInterface;
use Magento\Framework\GraphQl\Schema\Type\ResolveInfo;
use {Vendor}\{Module}\Api\Data\{Entity}InterfaceFactory;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class Create{Entity} implements ResolverInterface
{
    /**
     * Constructor.
     *
     * @param \{Vendor}\{Module}\Api\Data\{Entity}InterfaceFactory $factory
     * @param \{Vendor}\{Module}\Api\{Entity}RepositoryInterface $repository
     */
    public function __construct(
        private readonly {Entity}InterfaceFactory $factory,
        private readonly {Entity}RepositoryInterface $repository,
    ) {
    }

    /**
     * Resolve the create {Entity} mutation.
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
        if ($context->getExtensionAttributes()->getIsCustomer() === false) {
            throw new GraphQlAuthorizationException(__('Current customer does not have access'));
        }

        if (empty($args['input']['name'])) {
            throw new GraphQlInputException(__('"name" is required'));
        }

        $entity = $this->factory->create();
        $entity->setName((string) $args['input']['name']);

        $saved = $this->repository->save($entity);

        return [
            'id' => $saved->getId(),
            'name' => $saved->getName(),
        ];
    }
}
