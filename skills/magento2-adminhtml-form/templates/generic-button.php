<?php
/**
 * Shared button helper for the {Vendor}\{Module} {Entity} edit form buttons.
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/GenericButton.php
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Backend\Block\Widget\Context;

class GenericButton
{
    /**
     * @var Context
     */
    protected $context;

    /**
     * @param Context $context
     */
    public function __construct(Context $context)
    {
        $this->context = $context;
    }

    /**
     * Return the entity id from the request, or null for a new record.
     *
     * @return int|null
     */
    public function get{Entity}Id()
    {
        return $this->context->getRequest()->getParam('{entity}_id') ?: null;
    }

    /**
     * Generate a backend URL.
     *
     * @param string $route
     * @param array $params
     * @return string
     */
    public function getUrl($route = '', array $params = [])
    {
        return $this->context->getUrlBuilder()->getUrl($route, $params);
    }
}
