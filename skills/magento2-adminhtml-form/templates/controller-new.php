<?php
/**
 * "New" admin controller for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Controller/Adminhtml/{Entity}/NewAction.php
 * (class is NewAction because `New` is a reserved word; URL action is /new).
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Controller\Adminhtml\{Entity};

use Magento\Backend\App\Action;
use Magento\Backend\Model\View\Result\ForwardFactory;
use Magento\Framework\App\Action\HttpGetActionInterface;

class NewAction extends Action implements HttpGetActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{Module}::{entity}';

    /**
     * @var ForwardFactory
     */
    private $resultForwardFactory;

    /**
     * @param Action\Context $context
     * @param ForwardFactory $resultForwardFactory
     */
    public function __construct(Action\Context $context, ForwardFactory $resultForwardFactory)
    {
        parent::__construct($context);
        $this->resultForwardFactory = $resultForwardFactory;
    }

    /**
     * Forward to the edit screen.
     *
     * @return \Magento\Backend\Model\View\Result\Forward
     */
    public function execute()
    {
        return $this->resultForwardFactory->create()->forward('edit');
    }
}
