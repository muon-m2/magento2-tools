<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Attribute\Frontend;

use Magento\Eav\Model\Entity\Attribute\Frontend\AbstractFrontend;
use Magento\Framework\DataObject;

/**
 * Frontend model for the {attribute_code} attribute.
 *
 * Transforms the stored value before display. Use only when the displayed value
 * differs from the stored value (e.g. format date, mask sensitive data).
 */
final class {AttributeCode} extends AbstractFrontend
{
    /**
     * Get the value for display.
     *
     * @param DataObject $object
     * @return string|null
     */
    public function getValue($object)
    {
        $raw = parent::getValue($object);
        if ($raw === null || $raw === '') {
            return null;
        }

        // Custom transformation; replace with the desired display format.
        return (string) $raw;
    }
}
