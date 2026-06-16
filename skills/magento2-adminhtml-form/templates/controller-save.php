<?php
/**
 * "Save" admin controller for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Controller/Adminhtml/{Entity}/Save.php
 *
 * A standard UI form posts FLAT field data — getPostValue() returns [{entity}_id, ...fields].
 * Do NOT unwrap a data/general key. Empty id is normalised to null before save. On failure the
 * input is stashed in the data persistor so the form repopulates.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Controller\Adminhtml\{Entity};

use Magento\Backend\App\Action;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\App\Request\DataPersistorInterface;
use Magento\Framework\Data\Form\FormKey\Validator as FormKeyValidator;
use Magento\Framework\Exception\NoSuchEntityException;
use {Vendor}\{Module}\Model\{Entity}Factory;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class Save extends Action implements HttpPostActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{Module}::{entity}';

    /**
     * @var {Entity}RepositoryInterface
     */
    private ${entity}Repository;

    /**
     * @var {Entity}Factory
     */
    private ${entity}Factory;

    /**
     * @var DataPersistorInterface
     */
    private $dataPersistor;

    /**
     * @var FormKeyValidator
     */
    private $formKeyValidator;

    /**
     * @param Action\Context $context
     * @param {Entity}RepositoryInterface ${entity}Repository
     * @param {Entity}Factory ${entity}Factory
     * @param DataPersistorInterface $dataPersistor
     * @param FormKeyValidator $formKeyValidator
     */
    public function __construct(
        Action\Context $context,
        {Entity}RepositoryInterface ${entity}Repository,
        {Entity}Factory ${entity}Factory,
        DataPersistorInterface $dataPersistor,
        FormKeyValidator $formKeyValidator
    ) {
        parent::__construct($context);
        $this->{entity}Repository = ${entity}Repository;
        $this->{entity}Factory = ${entity}Factory;
        $this->dataPersistor = $dataPersistor;
        $this->formKeyValidator = $formKeyValidator;
    }

    /**
     * Persist the submitted form data.
     *
     * @return \Magento\Backend\Model\View\Result\Redirect
     */
    public function execute()
    {
        /** @var \Magento\Backend\Model\View\Result\Redirect $resultRedirect */
        $resultRedirect = $this->resultRedirectFactory->create();

        if (!$this->formKeyValidator->validate($this->getRequest())) {
            $this->messageManager->addErrorMessage(__('Invalid form key. Please try again.'));
            return $resultRedirect->setPath('*/*/');
        }

        $data = $this->getRequest()->getPostValue();

        if (!$data) {
            return $resultRedirect->setPath('*/*/');
        }

        $id = (int) ($data['{entity}_id'] ?? 0);
        if (empty($data['{entity}_id'])) {
            $data['{entity}_id'] = null;
        }

        try {
            $model = $id ? $this->{entity}Repository->getById($id) : $this->{entity}Factory->create();
            $model->setData($data);
            $this->{entity}Repository->save($model);

            $this->messageManager->addSuccessMessage(__('You saved the {Entity}.'));
            $this->dataPersistor->clear('{vendor_lower}_{entity}');

            if ($this->getRequest()->getParam('back')) {
                return $resultRedirect->setPath(
                    '*/*/edit',
                    ['{entity}_id' => $model->getId(), '_current' => true]
                );
            }

            return $resultRedirect->setPath('*/*/');
        } catch (NoSuchEntityException $e) {
            $this->messageManager->addErrorMessage(__('This {Entity} no longer exists.'));
            return $resultRedirect->setPath('*/*/');
        } catch (\Exception $e) {
            $this->messageManager->addExceptionMessage($e, __('Something went wrong while saving the {Entity}.'));
            $this->dataPersistor->set('{vendor_lower}_{entity}', $data);

            return $resultRedirect->setPath('*/*/edit', ['{entity}_id' => $id ?: null, '_current' => true]);
        }
    }
}
