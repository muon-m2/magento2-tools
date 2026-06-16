# Validation Rules

UI-form fields validate client-side via a `<validation>` block; the server must re-validate in the
Save controller (client validation is convenience, not security).

## Declarative rules (in `<field><settings><validation>`)

```xml
<validation>
    <rule name="required-entry" xsi:type="boolean">true</rule>
    <rule name="validate-number" xsi:type="boolean">true</rule>
</validation>
```

Common built-in rules: `required-entry`, `validate-no-empty`, `validate-number`,
`validate-digits`, `validate-email`, `validate-url`, `validate-alphanum`, `less-than-equals-to`,
`greater-than-equals-to`, `validate-zip-international`. Rules come from Magento's `mage/validation`.

## Required as a shorthand

`<settings><required>true</required></settings>` is equivalent to a `required-entry` rule for simple
required fields.

## Custom rule

Register a JS validator via a RequireJS mixin on `Magento_Ui/js/lib/validation/validator`, then
reference it by name in `<rule name="my-rule">`. Keep custom rules rare — prefer built-ins.

## Server-side (always)

In the Save controller, never trust the post. Validate required fields and types before
`repository->save()`, and on failure stash the input in the data persistor and redirect back with an
error message (see controllers-and-routing.md). This is what makes the form safe even if a client
bypasses JS.

## Dependent required-ness

A field that is only required when another field has a value pairs validation with field dependency —
see dependent-fields.md.
