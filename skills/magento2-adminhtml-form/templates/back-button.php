<?php
/**
 * "Back" button for the {Vendor}\{Module} {Entity} edit form.
 * Target: {Vendor}/{Module}/Block/Adminhtml/{Entity}/Edit/BackButton.php
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Block\Adminhtml\{Entity}\Edit;

use Magento\Framework\View\Element\UiComponent\Control\ButtonProviderInterface;

class BackButton extends GenericButton implements ButtonProviderInterface
{
    /**
     * @inheritDoc
     *
     * @return array<string, mixed>
     */
    public function getButtonData(): array
    {
        return [
            'label' => __('Back'),
            'on_click' => sprintf("location.href = '%s';", $this->getUrl('*/*/')),
            'class' => 'back',
            'sort_order' => 10,
        ];
    }
}
