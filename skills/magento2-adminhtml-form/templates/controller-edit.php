<?php
/**
 * "Edit" admin controller for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Controller/Adminhtml/{Entity}/Edit.php
 *
 * The DataProvider (not the registry) feeds the UI form; this controller only guards the
 * missing-entity case and sets the page title. Verify the repository method name matches the
 * actual interface (getById vs get).
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Controller\Adminhtml\{Entity};

use Magento\Backend\App\Action;
use Magento\Framework\App\Action\HttpGetActionInterface;
use Magento\Framework\Controller\ResultFactory;
use Magento\Framework\Exception\NoSuchEntityException;
use {Vendor}\{Module}\Api\{Entity}RepositoryInterface;

class Edit extends Action implements HttpGetActionInterface
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
     * Render the edit form, or redirect when the requested entity no longer exists.
     *
     * @return \Magento\Framework\Controller\ResultInterface
     */
    public function execute()
    {
        $id = (int) $this->getRequest()->getParam('{entity}_id');

        if ($id) {
            try {
                $this->{entity}Repository->getById($id);
            } catch (NoSuchEntityException $e) {
                $this->messageManager->addErrorMessage(__('This {Entity} no longer exists.'));
                return $this->resultRedirectFactory->create()->setPath('*/*/');
            }
        }

        /** @var \Magento\Framework\View\Result\Page $resultPage */
        $resultPage = $this->resultFactory->create(ResultFactory::TYPE_PAGE);
        $resultPage->setActiveMenu('{Vendor}_{Module}::{entity}');
        $resultPage->getConfig()->getTitle()->prepend($id ? __('Edit {Entity}') : __('New {Entity}'));

        return $resultPage;
    }
}
