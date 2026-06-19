# system.xml Anatomy

`etc/adminhtml/system.xml` is the file that populates **Stores → Configuration** in the
Magento admin. It is a merge file: multiple modules contribute nodes that Magento merges
at runtime.

## Top-level structure

```xml
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Config:etc/system_file.xsd">
    <system>
        <tab id="general" label="General" sortOrder="100"/>  <!-- optional; reuse existing tab -->

        <section id="acme_checkout" translate="label" type="text" sortOrder="300"
                 showInDefault="1" showInWebsite="1" showInStore="1">
            <label>Acme Checkout</label>
            <tab>general</tab>
            <resource>Acme_Checkout::config</resource>

            <group id="general" translate="label" type="text" sortOrder="10"
                   showInDefault="1" showInWebsite="1" showInStore="1">
                <label>General Settings</label>

                <field id="enable" translate="label" type="select" sortOrder="10"
                       showInDefault="1" showInWebsite="1" showInStore="1">
                    <label>Enable Module</label>
                    <source_model>Magento\Config\Model\Config\Source\Yesno</source_model>
                </field>

            </group>
        </section>
    </system>
</config>
```

## Section

| Attribute | Required | Notes |
|-----------|----------|-------|
| `id` | yes | snake_case; conventionally `{vendor_lower}_{module_lower}` |
| `translate` | yes | Always `"label"` |
| `type` | yes | Always `"text"` for sections |
| `sortOrder` | yes | Integer; controls sidebar order |
| `showInDefault` | yes | `1` or `0` |
| `showInWebsite` | yes | `1` or `0` |
| `showInStore` | yes | `1` or `0` |

Child elements: `<label>`, `<tab>` (id of the tab), `<resource>` (ACL), `<group>+`.

## Group

Same attribute set as `<section>` except `id` is a short snake_case name
(`general`, `api`, `display`, etc.). Child elements: `<label>`, `<comment>`,
`<field>+`.

## Field

| Attribute | Required | Notes |
|-----------|----------|-------|
| `id` | yes | snake_case field name |
| `translate` | yes | `"label"` or `"label comment"` |
| `type` | yes | See `field-types.md` |
| `sortOrder` | yes | Integer |
| `showInDefault` | yes | `1` or `0` |
| `showInWebsite` | yes | `1` or `0` |
| `showInStore` | yes | `1` or `0` |

Child elements:

| Element | Purpose |
|---------|---------|
| `<label>` | Human-readable label |
| `<comment>` | Help text below the field |
| `<source_model>` | FQCN; required for `select` / `multiselect` |
| `<backend_model>` | FQCN; for validation, transformation, or encryption |
| `<frontend_model>` | FQCN; custom rendering (e.g. buttons) |
| `<validate>` | Space-separated Magento JS validators, e.g. `required-entry` |
| `<can_be_empty>` | `1` for multiselect to allow no selection |
| `<depends>` | Conditional visibility; see below |

## depends — conditional visibility

```xml
<depends>
    <field id="enable">1</field>
</depends>
```

The `<field id>` attribute is the sibling field's `id` (no path prefix needed within the
same group). The text content is the value that must be selected for the depending field
to appear.

## source_model / backend_model / frontend_model hooks

- **source_model** — implements `Magento\Framework\Data\OptionSourceInterface` (or the
  legacy `Magento\Framework\Option\ArrayInterface`); returned array drives the dropdown.
  Standard library sources: `Magento\Config\Model\Config\Source\Yesno`,
  `Magento\Config\Model\Config\Source\Store`, `Magento\Config\Model\Config\Source\Website`.
- **backend_model** — extends `Magento\Framework\App\Config\Value`; called on save/load
  for validation, transformation, or encryption. The Encrypted backend model is the
  canonical secret handler.
- **frontend_model** — extends `Magento\Config\Block\System\Config\Form\Field`; for
  custom rendering (buttons, colour pickers, etc.).

## Merge safety

`system.xml` is collected and merged by Magento's XSD-aware loader. Always use the
`urn:magento:module:Magento_Config:etc/system_file.xsd` schema location. Do not clobber
an existing `system.xml`; append or merge the new section/group/field nodes.
