<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\{ControllerName};

use Magento\Framework\App\Action\HttpGetActionInterface;
use Magento\Framework\Controller\Result\Forward;
use Magento\Framework\Controller\Result\ForwardFactory;
use Magento\Framework\Controller\ResultFactory;
use Magento\Framework\Controller\ResultInterface;
use Magento\Framework\View\Result\Page;

/**
 * Frontend controller: {action description}.
 */
class {ActionName} implements HttpGetActionInterface
{
    /**
     * @param \Magento\Framework\Controller\ResultFactory $resultFactory
     */
    public function __construct(
        private readonly ResultFactory $resultFactory,
    ) {
    }

    /**
     * Execute the action and return a result instance.
     *
     * @return \Magento\Framework\Controller\ResultInterface
     */
    public function execute(): ResultInterface
    {
        /** @var Page $result */
        $result = $this->resultFactory->create(ResultFactory::TYPE_PAGE);
        $result->getConfig()->getTitle()->set(__('{Default Page Title}'));
        return $result;
    }
}
