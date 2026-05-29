<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Attribute\Backend;

use Magento\Eav\Model\Entity\Attribute\Backend\AbstractBackend;
use Magento\Framework\DataObject;

/**
 * Backend model for EAV attribute `{attribute_code}`.
 *
 * Use a backend model to transform the value on the way in (beforeSave) or out
 * (afterLoad). For trivial scalar attributes, no backend model is needed.
 */
class {BackendName} extends AbstractBackend
{
    /**
     * Transform value before persisting.
     *
     * @param \Magento\Framework\DataObject $object
     * @return self
     */
    public function beforeSave($object): self
    {
        $code = $this->getAttribute()->getAttributeCode();
        $value = $object->getData($code);
        if ($value !== null) {
            // Normalize / validate $value here.
            $object->setData($code, $value);
        }
        return parent::beforeSave($object);
    }

    /**
     * Transform value after loading from the database.
     *
     * @param \Magento\Framework\DataObject $object
     * @return self
     */
    public function afterLoad($object): self
    {
        // Optional post-load transformation.
        return parent::afterLoad($object);
    }
}
