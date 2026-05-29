# Email Template Rules

## File Structure

```
{Vendor}/{Module}/
├── view/frontend/email/
│   └── my-email.html
├── etc/
│   ├── email_templates.xml      # Template registration
│   └── config.xml               # Default path (templates_section)
```

## Template HTML

```html
<!--@subject My Notification: {{var data.subject}} @-->
<!--@vars {
"var data.first_name":"Recipient first name",
"var data.subject":"Email subject"
} @-->
<!--@styles
table { width: 100%; }
.cta { background: #1a73e8; color: white; padding: 8px 16px; }
@-->
{{template config_path="design/email/header_template"}}

<p>Hello {{var data.first_name}},</p>
<p>Your subject is: {{var data.subject}}.</p>

<p><a href="{{var data.url}}" class="cta">View details</a></p>

{{template config_path="design/email/footer_template"}}
```

Required directives:
- `@subject` — email subject
- `@vars` — declared variables (admin email editor uses this for autocomplete)
- `@styles` — inline CSS (Magento inlines `@styles` into the rendered email)

## Registration

```xml
<!-- etc/email_templates.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Email:etc/email_templates.xsd">
    <template id="{vendor_lower}_{module_lower}_my_email"
              label="My Email"
              file="my-email.html"
              type="html"
              module="{Vendor}_{Module}"
              area="frontend"/>
</config>
```

The skill APPENDS to existing `email_templates.xml` — never overwrites.

## Default Config Path

```xml
<!-- etc/config.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Store:etc/config.xsd">
    <default>
        <{vendor_lower}_{module_lower}>
            <email>
                <template>{vendor_lower}_{module_lower}_my_email</template>
                <sender>general</sender>
            </email>
        </{vendor_lower}_{module_lower}>
    </default>
</config>
```

Admin can override the template via Stores → Config → {Section} → Email Settings.

## Sending the Email

```php
$this->transportBuilder
    ->setTemplateIdentifier($this->scopeConfig->getValue('{vendor_lower}_{module_lower}/email/template'))
    ->setTemplateOptions(['area' => Area::AREA_FRONTEND, 'store' => $storeId])
    ->setTemplateVars($vars)
    ->setFromByScope($this->scopeConfig->getValue('{vendor_lower}_{module_lower}/email/sender'))
    ->addTo($email, $name)
    ->getTransport()
    ->sendMessage();
```

## Variable Escaping

Magento auto-escapes `{{var ...}}`. For trusted HTML (e.g. rendered Markdown):

```
{{var data.html_content|raw}}
```

Use `|raw` ONLY when the content is verified safe.

## Common Mistakes

- Forgetting `@subject` directive — email sends with empty subject.
- Putting `<style>` blocks in `<head>` — many email clients strip them. Use `@styles`.
- Hardcoded URLs — use `{{store url=""}}` instead.
- Forgetting `area=frontend` in `setTemplateOptions` — admin-area email may use wrong theme.
