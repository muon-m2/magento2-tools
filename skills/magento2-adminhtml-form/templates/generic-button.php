<?php
/**
 * Shared button helper for the {Vendor}\{Module} {Entity} edit form buttons.
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/GenericButton.php
 *
 * Holds the admin Context so each concrete button can build URLs and read the edited entity id.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Backend\Block\Widget\Context;

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
    public function get{Entity}Id(): ?int
    {
        $id = $this->context->getRequest()->getParam('{entity}_id');
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
