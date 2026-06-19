<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Config\Backend;

use Magento\Framework\App\Config\Value;

/**
 * Backend model for the {FieldId} configuration field.
 *
 * Extends App\Config\Value (which itself extends AbstractModel) to add custom
 * validation or transformation logic on save/load. Override beforeSave(), afterSave(),
 * afterLoad(), or getValue() as needed.
 *
 * Target: {Vendor}/{Module}/Model/Config/Backend/{BackendModelName}.php
 *
 * Note: for simple encryption, use the built-in
 * Magento\Config\Model\Config\Backend\Encrypted instead of this class.
 */
class {BackendModelName} extends Value
{
    /**
     * Validate and/or transform the value before it is saved to core_config_data.
     *
     * @return $this
     * @throws \Magento\Framework\Exception\ValidatorException
     */
    public function beforeSave(): static
    {
        // Add validation or transformation here.
        // Example: trim whitespace
        $value = trim((string) $this->getValue());
        $this->setValue($value);

        return parent::beforeSave();
    }

    /**
     * Process the value after it is loaded from core_config_data.
     *
     * @return $this
     */
    public function afterLoad(): static
    {
        // Add any load-time processing here (e.g. type coercion).
        return parent::afterLoad();
    }
}
