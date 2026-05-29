# Backend Model Patterns

A backend model intercepts attribute save/load to transform values.

## When to Use a Backend Model

| Input type | Magento-provided backend | When to subclass |
|-----------|--------------------------|------------------|
| text / textarea / select | (none needed) | Custom validation only |
| multiselect | `Magento\Eav\Model\Entity\Attribute\Backend\ArrayBackend` | Custom serialization |
| date | `Magento\Eav\Model\Entity\Attribute\Backend\Datetime` | Custom timezone handling |
| price | `Magento\Catalog\Model\Product\Attribute\Backend\Price` | Custom rounding / formatting |
| image | `Magento\Catalog\Model\Product\Attribute\Backend\Image` | Custom path / mime check |

## Multiselect with ArrayBackend

```php
<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Attribute\Backend;

use Magento\Eav\Model\Entity\Attribute\Backend\ArrayBackend;

class Tags extends ArrayBackend
{
    /**
     * Custom validation before save.
     */
    public function beforeSave($object)
    {
        parent::beforeSave($object);
        $value = $object->getData($this->getAttribute()->getAttributeCode());
        if (is_string($value)) {
            $values = explode(',', $value);
            // Validate / normalize
            $object->setData($this->getAttribute()->getAttributeCode(), implode(',', array_filter(array_map('trim', $values))));
        }
        return $this;
    }
}
```

## Custom Validation

For text fields requiring custom validation (e.g. UPC checksum):

```php
namespace {Vendor}\{Module}\Model\Attribute\Backend;

use Magento\Eav\Model\Entity\Attribute\Backend\AbstractBackend;
use Magento\Framework\Exception\LocalizedException;

class Upc extends AbstractBackend
{
    public function validate($object)
    {
        $value = $object->getData($this->getAttribute()->getAttributeCode());
        if ($value && !$this->isValidUpc($value)) {
            throw new LocalizedException(__('Invalid UPC: %1', $value));
        }
        return parent::validate($object);
    }

    private function isValidUpc(string $upc): bool
    {
        // UPC-12 checksum logic
        return preg_match('/^\d{12}$/', $upc) === 1;
    }
}
```

## Loaded-Value Transformation

For backend models that transform on load (e.g. decrypt):

```php
public function afterLoad($object)
{
    $value = $object->getData($this->getAttribute()->getAttributeCode());
    if ($value !== null) {
        $object->setData($this->getAttribute()->getAttributeCode(), $this->decrypt($value));
    }
    return parent::afterLoad($object);
}

public function beforeSave($object)
{
    $value = $object->getData($this->getAttribute()->getAttributeCode());
    if ($value !== null) {
        $object->setData($this->getAttribute()->getAttributeCode(), $this->encrypt($value));
    }
    return parent::beforeSave($object);
}
```

## File Location

`{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Attribute/Backend/{AttributeCode}.php`

## Common Mistakes

- Forgetting to call `parent::beforeSave()` / `parent::afterLoad()`.
- Throwing exception types other than `LocalizedException` — those aren't caught by the
  admin form and produce ugly 500 errors.
- Modifying `$object` in unexpected ways (e.g. setting unrelated fields) — side effects
  leak into other code paths.
