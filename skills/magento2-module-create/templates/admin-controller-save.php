<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\App\Request\DataPersistorInterface;
use Magento\Framework\Controller\Result\Redirect;
use Magento\Framework\Controller\Result\RedirectFactory;
use Magento\Framework\Data\Form\FormKey\Validator as FormKeyValidator;
use Magento\Framework\Exception\NoSuchEntityException;
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
     * @param \Magento\Framework\App\Request\DataPersistorInterface $dataPersistor
     */
    public function __construct(
        Context $context,
        private readonly FormKeyValidator $formKeyValidator,
        private readonly RedirectFactory $redirectFactory,
        private readonly {EntityName}RepositoryInterface $repository,
        private readonly {EntityName}InterfaceFactory $entityFactory,
        private readonly DataPersistorInterface $dataPersistor,
    ) {
        parent::__construct($context);
    }

    /**
     * Save {entity} from POST data.
     *
     * On edit (a non-empty entity_id is posted) the existing record is loaded by id so the
     * save UPDATES it instead of inserting a duplicate; a fresh entity is created only when
     * no id is present. On failure the submitted data is stashed in the data persistor under
     * the key the form DataProvider reads, so the form repopulates.
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
        if (!$postData) {
            return $redirect->setPath('*/*/index');
        }

        $entityId = (int) ($postData['entity_id'] ?? 0);

        try {
            $entity = $entityId > 0
                ? $this->repository->getById($entityId)
                : $this->entityFactory->create();
            $entity->setName((string) ($postData['name'] ?? ''));
            $this->repository->save($entity);
            $this->messageManager->addSuccessMessage(__('{EntityName} saved successfully.'));
            return $redirect->setPath('*/*/index');
        } catch (NoSuchEntityException $e) {
            $this->messageManager->addErrorMessage(__('This {EntityName} no longer exists.'));
            return $redirect->setPath('*/*/index');
        } catch (\Magento\Framework\Exception\CouldNotSaveException $e) {
            $this->messageManager->addErrorMessage($e->getMessage());
            $this->dataPersistor->set('{vendor_lower}_{module_lower}_{entity}', $postData);
            return $redirect->setPath('*/*/index');
        }
    }
}
