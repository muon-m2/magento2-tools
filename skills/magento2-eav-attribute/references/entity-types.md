# Entity Types

Magento has four primary EAV entities. Each uses a different setup factory and has
different scope semantics.

## Product (`catalog_product`)

- Setup factory: `Magento\Eav\Setup\EavSetupFactory` — what this skill's product patch
  template injects, and sufficient for `EavSetup::addAttribute('catalog_product', ...)`.
- Alternative: `Magento\Catalog\Setup\CategorySetupFactory` (a real Catalog class wrapping
  EavSetup) when you need catalog-specific metadata helpers — prefer `EavSetupFactory`
  otherwise, for consistency with the template.
- Entity type ID: `Magento\Catalog\Model\Product::ENTITY` = `catalog_product`
- Scope: global, website, store
- Common attributes: text, textarea, select, multiselect, date, boolean, price, image,
  media_image
- Apply-to: `simple,configurable,virtual,grouped,bundle,downloadable`

## Customer (`customer`)

- Setup factory: `Magento\Customer\Setup\CustomerSetupFactory`
- Entity type ID: `Magento\Customer\Model\Customer::ENTITY` = `customer`
- Scope: global only (customer is not multi-store)
- Common attributes: text, select, boolean, date
- Special fields:
    - `is_used_in_grid` — show in admin customer grid
    - `is_visible_in_grid` — column visible by default
    - `is_filterable_in_grid` — searchable from grid filter
    - `is_searchable_in_grid` — included in quick search
- Forms: must specify which forms the attribute appears on (`adminhtml_customer`,
  `customer_account_create`, `customer_account_edit`)

## Customer Address (`customer_address`)

- Setup factory: `Magento\Customer\Setup\CustomerSetupFactory`
- Entity type ID: `Magento\Customer\Api\AddressMetadataInterface::ENTITY_TYPE_ADDRESS`
- Scope: global
- Forms: `adminhtml_customer_address`, `customer_address_edit`,
  `customer_register_address`

## Category (`catalog_category`)

- Setup factory: `Magento\Catalog\Setup\CategorySetupFactory`
- Entity type ID: `Magento\Catalog\Model\Category::ENTITY` = `catalog_category`
- Scope: global, store
- Common attributes: text, textarea, image, boolean

## Selection Rules

| User says                                 | Entity           |
|-------------------------------------------|------------------|
| "product attribute"                       | catalog_product  |
| "customer attribute"                      | customer         |
| "address attribute" or "customer address" | customer_address |
| "category attribute"                      | catalog_category |

If the user is unclear, ask: "Which entity type — product, customer, customer address,
or category?"
