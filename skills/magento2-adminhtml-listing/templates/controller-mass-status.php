<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\Controller\ResultInterface;
use Magento\Framework\Data\Form\FormKey\Validator as FormKeyValidator;
use Magento\Ui\Component\MassAction\Filter;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Mass enable/disable selected {EntityName} records. Set the status value via di.xml argument
 * `status` (1 = enable, 0 = disable) on two virtualTypes, or pass it through a shared base.
 */
class MassStatus extends Action implements HttpPostActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';

    /**
     * @param \Magento\Backend\App\Action\Context $context
     * @param \Magento\Ui\Component\MassAction\Filter $filter
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     * @param \Magento\Framework\Data\Form\FormKey\Validator $formKeyValidator
     * @param int $status
     */
    public function __construct(
        Context $context,
        private readonly Filter $filter,
        private readonly CollectionFactory $collectionFactory,
        private readonly FormKeyValidator $formKeyValidator,
        private readonly int $status = 1,
    ) {
        parent::__construct($context);
    }

    /**
     * @return \Magento\Framework\Controller\ResultInterface
     */
    public function execute(): ResultInterface
    {
        if (!$this->formKeyValidator->validate($this->getRequest())) {
            $this->messageManager->addErrorMessage(__('Invalid form key. Please try again.'));
            return $this->resultRedirectFactory->create()->setPath('*/*/');
        }

        $collection = $this->filter->getCollection($this->collectionFactory->create());
        $count = 0;
        foreach ($collection as $item) {
            $item->setData('status', $this->status);
            $item->save();
            $count++;
        }
        $this->messageManager->addSuccessMessage(__('A total of %1 record(s) have been updated.', $count));

        return $this->resultRedirectFactory->create()->setPath('*/*/');
    }
}
