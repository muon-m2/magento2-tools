# Extension Attributes

Extension attributes add fields to an existing `Api/Data` interface **without modifying it** — the
mechanism for one module to extend another module's DTO, and the BC-safe way to grow your own DTO
over time. They appear in the Web API response under an `extension_attributes` object.

## Declaration — `etc/extension_attributes.xml`

```xml
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:Api/etc/extension_attributes.xsd">
    <extension_attributes for="{Vendor}\{ModuleName}\Api\Data\{EntityName}Interface">
        <attribute code="extra_label" type="string"/>
        <attribute code="related_ids" type="int[]"/>
    </extension_attributes>
</config>
```

`bin/magento setup:di:compile` generates `{EntityName}ExtensionInterface` from this file. Accessors
become `getExtraLabel()` / `setExtraLabel()` on the generated extension object.

## The DTO accessor — return the generated interface, not the base

```php
/**
 * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null
 */
public function getExtensionAttributes(): ?\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface;
```

**Critical:** the return type must be the entity-specific generated interface, **not** the generic
`\Magento\Framework\Api\ExtensionAttributesInterface`. Using the generic base makes
`setup:di:compile` fail. (The base interface is empty; the generated one carries the typed
accessors.) The `data-interface.php` template already does this correctly.

## Populating extension attributes

Extension data is not loaded automatically — a `getList`/`getById` must populate it, typically via a
plugin on the repository (`afterGetList` / `afterGet`) so other modules can hook in. For your own
attributes you may set them in the repository before returning. Either way:

```php
$ext = $entity->getExtensionAttributes() ?? $this->extensionFactory->create();
$ext->setExtraLabel($label);
$entity->setExtensionAttributes($ext);
```

## When to use what

- **Extension attribute** — adding a field to a *published* DTO, or a field another module owns. BC-safe.
- **Direct interface field** — a field intrinsic to *your* entity that you control from the start.
  Add it to `{EntityName}Interface` directly (constant + getter/setter); no extension machinery needed.

Custom attributes (EAV-style `custom_attributes`) are a different mechanism for `CustomAttributesDataInterface`
entities — out of scope here unless the entity is EAV-backed.
