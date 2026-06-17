<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpGetActionInterface;
use Magento\Framework\View\Result\Page;
use Magento\Framework\View\Result\PageFactory;

/**
 * Admin {entity} grid controller.
 */
class Index extends Action implements HttpGetActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';

    /**
     * @param \Magento\Backend\App\Action\Context $context
     * @param \Magento\Framework\View\Result\PageFactory $pageFactory
     */
    public function __construct(
        Context $context,
        private readonly PageFactory $pageFactory,
    ) {
        parent::__construct($context);
    }

    /**
     * Render the {entity} grid page.
     *
     * @return \Magento\Framework\View\Result\Page
     */
    public function execute(): Page
    {
        $page = $this->pageFactory->create();
        $page->setActiveMenu('{Vendor}_{ModuleName}::main');
        $page->getConfig()->getTitle()->prepend(__('{EntityName} List'));

        return $page;
    }
}
