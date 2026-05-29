# Source Model Patterns

A source model provides the list of options for a `select` or `multiselect` attribute.

## Static Options

For a fixed option list:

```php
<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Source;

use Magento\Eav\Model\Entity\Attribute\Source\AbstractSource;

class Status extends AbstractSource
{
    /**
     * Return the option list.
     *
     * @return array<int, array{value: string, label: \Magento\Framework\Phrase}>
     */
    public function getAllOptions(): array
    {
        if ($this->_options === null) {
            $this->_options = [
                ['value' => 'pending', 'label' => __('Pending')],
                ['value' => 'approved', 'label' => __('Approved')],
                ['value' => 'rejected', 'label' => __('Rejected')],
            ];
        }
        return $this->_options;
    }
}
```

## Dynamic Options (from DB / Service)

For options driven by another entity (e.g. vendor list):

```php
<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Source;

use Magento\Eav\Model\Entity\Attribute\Source\AbstractSource;
use {Vendor}\Vendor\Api\VendorRepositoryInterface;
use Magento\Framework\Api\SearchCriteriaBuilder;

class VendorList extends AbstractSource
{
    public function __construct(
        private VendorRepositoryInterface $vendorRepository,
        private SearchCriteriaBuilder $searchCriteriaBuilder,
    ) {
    }

    /**
     * @return array<int, array{value: string, label: string}>
     */
    public function getAllOptions(): array
    {
        if ($this->_options === null) {
            $vendors = $this->vendorRepository->getList($this->searchCriteriaBuilder->create());
            $this->_options = array_map(
                fn ($v) => ['value' => (string) $v->getId(), 'label' => $v->getName()],
                $vendors->getItems()
            );
        }
        return $this->_options;
    }
}
```

## With "Please Select" Placeholder

Add a blank option at the top:

```php
public function getAllOptions(): array
{
    if ($this->_options === null) {
        $this->_options = [
            ['value' => '', 'label' => __('-- Please Select --')],
            ['value' => 'pending', 'label' => __('Pending')],
            // ...
        ];
    }
    return $this->_options;
}
```

## Required: DI Wiring

When using a source model, ensure it can be resolved by Magento's DI. For factory-style
instantiation (default for source models), no DI changes are required.

For dependency-injected source models (the dynamic options example), no special DI
config is needed — Magento resolves the constructor args automatically.

## Common Mistakes

- Returning array of strings instead of `['value' => ..., 'label' => ...]` — silently
  fails to render.
- Forgetting to cache via `$this->_options` — re-queries DB on every page render.
- Returning untranslated labels — admin labels should use `__()`.

## File Location

`src/app/code/{Vendor}/{Module}/Model/Source/{AttributeCode}.php`

## Reference

Magento core source models (good examples):
- `Magento\Catalog\Model\Product\Type` — product type source
- `Magento\Eav\Model\Entity\Attribute\Source\Boolean` — Yes/No
- `Magento\Cms\Model\Page\Source\PageLayout` — option list from config
