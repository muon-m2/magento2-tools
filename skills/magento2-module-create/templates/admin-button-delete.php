<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Block\Adminhtml\{EntityName}\Edit;

use Magento\Framework\View\Element\UiComponent\Control\ButtonProviderInterface;

/**
 * "Delete" button for the {EntityName} edit form. Rendered only when editing an existing
 * record (getEntityId() is non-null on the edit form, null on the "new" form).
 */
class DeleteButton extends GenericButton implements ButtonProviderInterface
{
    /**
     * @inheritDoc
     *
     * @return array<string, mixed>
     */
    public function getButtonData(): array
    {
        $entityId = $this->getEntityId();
        if ($entityId === null) {
            return [];
        }

        return [
            'label' => __('Delete'),
            'class' => 'delete',
            'on_click' => sprintf(
                "deleteConfirm('%s', '%s')",
                __('Are you sure you want to delete this {entity}?'),
                $this->getUrl('*/*/delete', ['entity_id' => $entityId])
            ),
            'sort_order' => 20,
        ];
    }
}
