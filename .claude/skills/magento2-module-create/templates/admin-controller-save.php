<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\Controller\Result\Redirect;
use Magento\Framework\Controller\Result\RedirectFactory;
use Magento\Framework\Data\Form\FormKey\Validator as FormKeyValidator;
use {Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}InterfaceFactory;

/**
 * Admin {entity} save controller.
 */
class Save extends Action implements HttpPostActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';

    /**
     * @param \Magento\Backend\App\Action\Context $context
     * @param \Magento\Framework\Data\Form\FormKey\Validator $formKeyValidator
     * @param \Magento\Framework\Controller\Result\RedirectFactory $redirectFactory
     * @param \{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface $repository
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}InterfaceFactory $entityFactory
     */
    public function __construct(
        Context $context,
        private readonly FormKeyValidator $formKeyValidator,
        private readonly RedirectFactory $redirectFactory,
        private readonly {EntityName}RepositoryInterface $repository,
        private readonly {EntityName}InterfaceFactory $entityFactory,
    ) {
        parent::__construct($context);
    }

    /**
     * Save {entity} from POST data.
     *
     * @return \Magento\Framework\Controller\Result\Redirect
     */
    public function execute(): Redirect
    {
        $redirect = $this->redirectFactory->create();

        if (!$this->formKeyValidator->validate($this->getRequest())) {
            $this->messageManager->addErrorMessage(__('Invalid form key. Please try again.'));
            return $redirect->setPath('*/*/index');
        }

        $postData = $this->getRequest()->getPostValue();

        try {
            $entity = $this->entityFactory->create();
            $entity->setName((string) ($postData['name'] ?? ''));
            $this->repository->save($entity);
            $this->messageManager->addSuccessMessage(__('{EntityName} saved successfully.'));
            return $redirect->setPath('*/*/index');
        } catch (\Magento\Framework\Exception\CouldNotSaveException $e) {
            $this->messageManager->addErrorMessage($e->getMessage());
            return $redirect->setPath('*/*/index');
        }
    }
}
