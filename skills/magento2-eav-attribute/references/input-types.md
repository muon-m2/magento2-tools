# Input Types

Magento EAV input types and their requirements.

## Standard Input Types

| Input type  | Backend type      | Required backend model                                    | Required source model                               |
|-------------|-------------------|-----------------------------------------------------------|-----------------------------------------------------|
| text        | varchar (default) | (none for ≤ 255 chars)                                    | (none)                                              |
| textarea    | text              | (none)                                                    | (none)                                              |
| select      | int / varchar     | (none for option-based)                                   | Source model required                               |
| multiselect | varchar           | `Magento\Eav\Model\Entity\Attribute\Backend\ArrayBackend` | Source model required                               |
| date        | datetime          | `Magento\Eav\Model\Entity\Attribute\Backend\Datetime`     | (none)                                              |
| boolean     | int               | (none)                                                    | `Magento\Eav\Model\Entity\Attribute\Source\Boolean` |
| price       | decimal           | `Magento\Catalog\Model\Product\Attribute\Backend\Price`   | (none)                                              |
| image       | varchar           | `Magento\Catalog\Model\Product\Attribute\Backend\Image`   | (none)                                              |
| media_image | varchar           | `Magento\Catalog\Model\Product\Attribute\Backend\Media`   | (none)                                              |
| weight      | decimal           | `Magento\Catalog\Model\Product\Attribute\Backend\Weight`  | (none)                                              |

## Custom Source Model (Select / Multiselect)

```php
namespace {Vendor}\{Module}\Model\Source;

use Magento\Eav\Model\Entity\Attribute\Source\AbstractSource;

class Status extends AbstractSource
{
    public function getAllOptions(): array
    {
        return [
            ['value' => 'pending', 'label' => __('Pending')],
            ['value' => 'approved', 'label' => __('Approved')],
            ['value' => 'rejected', 'label' => __('Rejected')],
        ];
    }
}
```

## Custom Backend Model (Multiselect / Image / non-trivial)

For multiselect storing serialized data, use:

```php
namespace {Vendor}\{Module}\Model\Attribute\Backend;

use Magento\Eav\Model\Entity\Attribute\Backend\ArrayBackend;

class Tags extends ArrayBackend
{
    public function beforeSave($object)
    {
        // Custom validation / transformation
        return parent::beforeSave($object);
    }
}
```

## Custom Frontend Model

Rarely needed. Use when the displayed value differs from the stored value:

```php
namespace {Vendor}\{Module}\Model\Attribute\Frontend;

use Magento\Eav\Model\Entity\Attribute\Frontend\AbstractFrontend;

class Display extends AbstractFrontend
{
    public function getValue($object)
    {
        $raw = parent::getValue($object);
        return $this->transform($raw);
    }
}
```

## Selection Rules

For Phase 1 input:

- User says "text field" → `text` (backend_type varchar)
- User says "long text" or "description" → `textarea` (backend_type text)
- User says "dropdown" or "select" → `select` + source model
- User says "multi-select" or "tags" → `multiselect` + ArrayBackend + source model
- User says "checkbox" or "yes/no" → `boolean`
- User says "price" → `price` + Price backend
- User says "image" → `image` + Image backend
- User says "date" → `date` + Datetime backend

If unclear: ask "What kind of value will this hold? text / long text / dropdown / yes-no /
date / price / image".
