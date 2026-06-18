# Scope and Config Paths

## Config path convention

Every Magento store-configuration value is addressed by a **config path** of the form:

```
{section_id}/{group_id}/{field_id}
```

By convention for custom modules:

```
{vendor_lower}_{module_lower}/{group_id}/{field_id}
```

All three segments are lowercase snake_case. Example:

```
acme_checkout/general/enable_feature
acme_catalog/api/api_key
```

This path is used in:

- `ScopeConfigInterface::getValue($path, $scopeType, $scopeCode)`
- `ScopeConfigInterface::isSetFlag($path, $scopeType, $scopeCode)`
- `bin/magento config:set {path} {value}`
- `bin/magento config:show {path}`
- `config.xml` `<default>` tree

## Scope levels

Magento has three configuration scope levels, from broadest to narrowest:

| Level | Constant | `ScopeInterface` | Notes |
|-------|----------|-----------------|-------|
| Default | `ScopeConfigInterface::SCOPE_TYPE_DEFAULT` (`"default"`) | — | Falls back when no website/store-view override exists |
| Website | `\Magento\Store\Model\ScopeInterface::SCOPE_WEBSITE` (`"website"`) | `$scopeCode` = website code or id |
| Store view | `\Magento\Store\Model\ScopeInterface::SCOPE_STORE` (`"store"`) | `$scopeCode` = store view code or id |

The typed reader should use `SCOPE_STORE` by default (the narrowest) so that store-view
overrides are honoured. Pass the current store id as `$scopeCode` for frontend context;
pass `null` in backend/CLI context (falls back through website → default).

## showInDefault / showInWebsite / showInStore flags

These control where the field appears in the admin UI:

| Flag | Meaning |
|------|---------|
| `showInDefault="1"` | Visible at the Global (default) scope |
| `showInWebsite="1"` | Visible at the Website scope |
| `showInStore="1"` | Visible at the Store View scope |

A field with `showInStore="0"` cannot be overridden at the store-view level.

**Common combinations:**

```xml
<!-- Global-only setting (no per-store override) -->
showInDefault="1" showInWebsite="0" showInStore="0"

<!-- Global + website override only -->
showInDefault="1" showInWebsite="1" showInStore="0"

<!-- Full hierarchy (most flexible) -->
showInDefault="1" showInWebsite="1" showInStore="1"
```

## config.xml — default values

`etc/config.xml` sets the default values for the `"default"` scope. Its structure mirrors
the config path:

```xml
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:App/etc/config.xsd">
    <default>
        <{section_id}>
            <{group_id}>
                <{field_id}>{DefaultValue}</{field_id}>
            </{group_id}>
        </{section_id}>
    </default>
</config>
```

If no `config.xml` entry exists for a field, `getValue()` returns `null`.

## Reading with the correct scope in code

```php
// Store-aware read (resolves narrowest applicable override):
$value = $this->scopeConfig->getValue(
    'acme_checkout/general/enable_feature',
    \Magento\Store\Model\ScopeInterface::SCOPE_STORE,
    $storeId
);

// Boolean flag read (returns bool):
$enabled = $this->scopeConfig->isSetFlag(
    'acme_checkout/general/enable_feature',
    \Magento\Store\Model\ScopeInterface::SCOPE_STORE,
    $storeId
);
```

The typed Config reader wraps these calls so business code never references the path
strings directly.

## CLI interaction

```bash
# Read current value at default scope
bin/magento config:show acme_checkout/general/enable_feature

# Set at default scope
bin/magento config:set acme_checkout/general/enable_feature 1

# Set at website scope
bin/magento config:set --scope website --scope-code base acme_checkout/general/enable_feature 0

# Set at store-view scope
bin/magento config:set --scope store --scope-code default acme_checkout/general/enable_feature 1
```
