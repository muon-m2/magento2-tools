<?php
/**
 * "Save and Continue Edit" button for the {Vendor}\{Module} {Entity} edit form.
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/SaveAndContinueButton.php
 * Only generate when the save-and-continue surface is requested.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Framework\View\Element\UiComponent\Control\ButtonProviderInterface;

class SaveAndContinueButton extends GenericButton implements ButtonProviderInterface
{
    /**
     * @inheritDoc
     *
     * @return array<string, mixed>
     */
    public function getButtonData(): array
    {
        return [
            'label' => __('Save and Continue Edit'),
            'class' => 'save',
            'data_attribute' => [
                'mage-init' => ['button' => ['event' => 'saveAndContinueEdit']],
            ],
            'sort_order' => 80,
        ];
    }
}
