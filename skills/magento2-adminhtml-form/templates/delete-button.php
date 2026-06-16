<?php
/**
 * "Delete" button for the {Vendor}\{Module} {Entity} edit form (hidden on the New screen).
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/DeleteButton.php
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Framework\View\Element\UiComponent\Control\ButtonProviderInterface;

class DeleteButton extends GenericButton implements ButtonProviderInterface
{
    /**
     * @inheritDoc
     *
     * @return array<string, mixed>
     */
    public function getButtonData(): array
    {
        $entityId = $this->get{Entity}Id();
        if ($entityId === null) {
            return [];
        }

        return [
            'label' => __('Delete {Entity}'),
            'class' => 'delete',
            'on_click' => sprintf(
                "deleteConfirm('%s', '%s')",
                __('Are you sure you want to delete this?'),
                $this->getUrl('*/*/delete', ['{entity}_id' => $entityId])
            ),
            'sort_order' => 20,
        ];
    }
}
