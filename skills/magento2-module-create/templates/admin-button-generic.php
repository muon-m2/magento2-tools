<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Block\Adminhtml\{EntityName}\Edit;

use Magento\Backend\Block\Widget\Context;

/**
 * Shared base for the {EntityName} edit-form buttons. Holds the admin Context so each
 * concrete button can build URLs and read the edited entity id from the request.
 */
class GenericButton
{
    /**
     * @param \Magento\Backend\Block\Widget\Context $context
     */
    public function __construct(
        protected readonly Context $context,
    ) {
    }

    /**
     * Return the id of the entity currently being edited, or null on the "new" form.
     *
     * @return int|null
     */
    public function getEntityId(): ?int
    {
        $id = $this->context->getRequest()->getParam('entity_id');
        return $id !== null ? (int) $id : null;
    }

    /**
     * Generate an admin URL for the given route.
     *
     * @param string $route
     * @param array $params
     * @return string
     */
    public function getUrl(string $route = '', array $params = []): string
    {
        return $this->context->getUrlBuilder()->getUrl($route, $params);
    }
}
