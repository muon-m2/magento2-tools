<?php
/**
 * "Delete" admin controller for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Controller/Adminhtml/{Entity}/Delete.php
 *
 * Reached via the DeleteButton's deleteConfirm() GET navigation; the admin secret URL key
 * provides CSRF protection for admin GET actions. Verify the repository method name matches the
 * actual interface (deleteById vs delete).
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Controller\Adminhtml\{Entity};

use Magento\Backend\App\Action;
use Magento\Framework\App\Action\HttpGetActionInterface;
use Magento\Framework\Exception\NoSuchEntityException;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class Delete extends Action implements HttpGetActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{Module}::{entity}';

    /**
     * @var {Entity}RepositoryInterface
     */
    private ${entity}Repository;

    /**
     * @param Action\Context $context
     * @param {Entity}RepositoryInterface ${entity}Repository
     */
    public function __construct(Action\Context $context, {Entity}RepositoryInterface ${entity}Repository)
    {
        parent::__construct($context);
        $this->{entity}Repository = ${entity}Repository;
    }

    /**
     * Delete the requested entity.
     *
     * @return \Magento\Backend\Model\View\Result\Redirect
     */
    public function execute()
    {
        /** @var \Magento\Backend\Model\View\Result\Redirect $resultRedirect */
        $resultRedirect = $this->resultRedirectFactory->create();
        $id = (int) $this->getRequest()->getParam('{entity}_id');

        if (!$id) {
            $this->messageManager->addErrorMessage(__('We can\'t find a {Entity} to delete.'));
            return $resultRedirect->setPath('*/*/');
        }

        try {
            $this->{entity}Repository->deleteById($id);
            $this->messageManager->addSuccessMessage(__('You deleted the {Entity}.'));
        } catch (NoSuchEntityException $e) {
            $this->messageManager->addErrorMessage(__('This {Entity} no longer exists.'));
        } catch (\Exception $e) {
            $this->messageManager->addExceptionMessage($e, __('Something went wrong while deleting the {Entity}.'));
            return $resultRedirect->setPath('*/*/edit', ['{entity}_id' => $id]);
        }

        return $resultRedirect->setPath('*/*/');
    }
}
