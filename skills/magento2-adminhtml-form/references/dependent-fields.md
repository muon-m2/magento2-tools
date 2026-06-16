# Dependent / Conditional Fields

Show, hide, enable, or disable a field based on another field's value — the admin equivalent of
`Magento\Config\Model\Config\Structure` `depends`, done with UI-component `imports`/`exports` links
or a `switcherConfig`. ([S11])

## Pattern A — show/hide via `imports` (most common)

The dependent field imports the controller field's value and toggles its own `visible`/`disabled`:

```xml
<field name="redirect_url" formElement="input">
    <settings>
        <dataType>text</dataType>
        <label translate="true">Redirect URL</label>
        <imports>
            <link name="visible">${ $.provider }:${ $.parentScope }.redirect_type</link>
        </imports>
    </settings>
</field>
```

For value-specific visibility, use a small custom component or `switcherConfig` (below) — a plain
`imports` link toggles on truthiness.

## Pattern B — `switcherConfig` (value-mapped rules)

On the **controller** field, declare rules that enable/disable targets per chosen value:

```xml
<settings>
    <switcherConfig>
        <enabled>true</enabled>
        <rules>
            <rule name="0"><value>1</value><actions>
                <action name="0"><target>${ $.provider }:data.redirect_url</target><callback>show</callback></action>
            </actions></rule>
        </rules>
    </switcherConfig>
</settings>
```

## Pattern C — dynamicRows visibility

Inside `dynamicRows`, per-row field dependency uses the same `imports` with the record's dataScope.
See field-types.md.

## Keep it server-safe

Visibility is cosmetic. If a hidden field must not be saved, also drop/ignore it in the Save
controller — don't rely on the client hiding it. See validation-rules.md.

## Sources
- [S11] dev.to/rain2o — Using field dependency in Magento 2: https://dev.to/rain2o/using-field-dependency-in-magento-2-2ca
