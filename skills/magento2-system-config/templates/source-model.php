<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Config\Source;

use Magento\Framework\Data\OptionSourceInterface;

/**
 * Source model for the {FieldId} configuration field.
 *
 * Returns the option array for a system.xml select or multiselect field.
 * Target: {Vendor}/{Module}/Model/Config/Source/{SourceName}.php
 */
class {SourceName} implements OptionSourceInterface
{
    public const VALUE_OPTION_A = '1';
    public const VALUE_OPTION_B = '2';

    /**
     * Return the list of options for the admin configuration field.
     *
     * @return array<int, array{value: string, label: \Magento\Framework\Phrase}>
     */
    public function toOptionArray(): array
    {
        return [
            ['value' => self::VALUE_OPTION_A, 'label' => __('Option A')],
            ['value' => self::VALUE_OPTION_B, 'label' => __('Option B')],
        ];
    }
}
