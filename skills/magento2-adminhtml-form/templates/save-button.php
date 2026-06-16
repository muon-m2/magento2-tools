<?php
/**
 * "Save" button for the {Vendor}\{Module} {Entity} edit form.
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/SaveButton.php
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Framework\View\Element\UiComponent\Control\ButtonProviderInterface;

class SaveButton extends GenericButton implements ButtonProviderInterface
{
    /**
     * @return array
     */
    public function getButtonData()
    {
        return [
            'label' => __('Save {Entity}'),
            'class' => 'save primary',
            'data_attribute' => [
                'mage-init' => ['button' => ['event' => 'save']],
                'form-role' => 'save',
            ],
            'sort_order' => 90,
        ];
    }
}
