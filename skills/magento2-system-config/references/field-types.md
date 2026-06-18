# Field Types in system.xml

The `type` attribute on `<field>` controls the HTML input rendered in
Stores → Configuration.

## Core types

| Type | Rendered as | Notes |
|------|-------------|-------|
| `text` | `<input type="text">` | Default; single-line string |
| `textarea` | `<textarea>` | Multi-line string |
| `select` | `<select>` (single) | Requires `<source_model>` |
| `multiselect` | `<select multiple>` | Requires `<source_model>` and `<can_be_empty>1</can_be_empty>` |
| `file` | `<input type="file">` | File upload; backend model handles storage |
| `obscure` | `<input type="password">` | Masks the value in the UI; always pair with Encrypted backend model for persistence (see `encrypted-fields.md`) |
| `image` | Image upload + preview | Requires `Magento\Config\Model\Config\Backend\Image` backend model |
| `button` | Custom block | Requires `<frontend_model>` pointing to a `Magento\Config\Block\System\Config\Form\Field` subclass |
| `label` | Read-only text | Displays a static label; no user input |
| `hidden` | `<input type="hidden">` | Not visible; rarely needed in admin config |

## Common source_model shortcuts

| Use case | FQCN |
|----------|------|
| Yes/No toggle | `Magento\Config\Model\Config\Source\Yesno` |
| Enabled/Disabled | `Magento\Config\Model\Config\Source\Enabledisable` |
| All store views | `Magento\Config\Model\Config\Source\Store` |
| All websites | `Magento\Config\Model\Config\Source\Website` |
| All locales | `Magento\Config\Model\Config\Source\Locale` |
| All currencies | `Magento\Config\Model\Config\Source\Currency` |
| Custom | `{Vendor}\{Module}\Model\Config\Source\{SourceName}` |

## Boolean / toggle fields

Use `type="select"` + `source_model="Magento\Config\Model\Config\Source\Yesno"`.
Read in the typed reader with `isSetFlag()` (returns `bool`), NOT `getValue()`.

```xml
<field id="enable" translate="label" type="select" sortOrder="10"
       showInDefault="1" showInWebsite="1" showInStore="1">
    <label>Enable</label>
    <source_model>Magento\Config\Model\Config\Source\Yesno</source_model>
</field>
```

## Multiselect fields

```xml
<field id="allowed_methods" translate="label" type="multiselect" sortOrder="20"
       showInDefault="1" showInWebsite="1" showInStore="0">
    <label>Allowed Methods</label>
    <source_model>Acme\Checkout\Model\Config\Source\PaymentMethod</source_model>
    <can_be_empty>1</can_be_empty>
</field>
```

The stored value is a comma-separated string. The typed reader should call `getValue()`
and split on `,`, or use `explode(',', (string) $value)`.

## Password / secret fields

Use `type="obscure"` + Encrypted backend model. See `encrypted-fields.md` for full
details.

```xml
<field id="api_key" translate="label" type="obscure" sortOrder="30"
       showInDefault="1" showInWebsite="1" showInStore="0">
    <label>API Key</label>
    <backend_model>Magento\Config\Model\Config\Backend\Encrypted</backend_model>
</field>
```

## Button (custom frontend model)

```xml
<field id="sync" translate="label" type="button" sortOrder="100"
       showInDefault="1" showInWebsite="0" showInStore="0">
    <label>Sync Now</label>
    <frontend_model>Acme\Module\Block\Adminhtml\System\Config\SyncButton</frontend_model>
</field>
```

The `frontend_model` must extend `Magento\Config\Block\System\Config\Form\Field` and
override `_getElementHtml()`.

## Choosing the right type

1. Simple text → `text`
2. Long text or JSON → `textarea`
3. One-of-N options → `select` + source model
4. Multiple-of-N options → `multiselect` + source model + `<can_be_empty>1`
5. Secret / API key → `obscure` + Encrypted backend model
6. On/off flag → `select` + `Yesno` source model; read with `isSetFlag()`
7. File upload → `file` + backend model
8. Custom button → `button` + frontend model
