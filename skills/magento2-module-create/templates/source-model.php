<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Source;

use Magento\Eav\Model\Entity\Attribute\Source\AbstractSource;

/**
 * Source model for EAV attribute `{attribute_code}`.
 */
class {SourceName} extends AbstractSource
{
    public const VALUE_OPTION_A = '1';
    public const VALUE_OPTION_B = '2';

    /**
     * Return the allowed values.
     *
     * @return mixed[]
     */
    public function getAllOptions(): array
    {
        if ($this->_options === null) {
            $this->_options = [
                ['value' => self::VALUE_OPTION_A, 'label' => __('Option A')],
                ['value' => self::VALUE_OPTION_B, 'label' => __('Option B')],
            ];
        }
        return $this->_options;
    }
}
