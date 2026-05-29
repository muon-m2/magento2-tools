# Canonical Placeholder Schema for Templates

All `.claude/skills/*/templates/` files use the placeholders defined below. Template-lint
checks should fail on any unknown placeholder, and substitution code should know exactly
these tokens.

## Canonical placeholders

| Placeholder         | Meaning                                            | Example         |
|---------------------|----------------------------------------------------|-----------------|
| `{Vendor}`          | PascalCase vendor prefix                           | `Acme`          |
| `{vendor}`          | lowercase vendor (composer / config keys)          | `acme`          |
| `{Module}`          | PascalCase module name                             | `OrderExport`   |
| `{module}`          | lowercase module (snake-case is *not* used here)   | `orderexport`   |
| `{AttributeCode}`   | PascalCase attribute identifier                    | `LoyaltyTier`   |
| `{attribute_code}`  | snake_case attribute identifier                    | `loyalty_tier`  |
| `{Code}`            | PascalCase short code (alias of `{AttributeCode}`) | `LoyaltyTier`   |
| `{code}`            | snake_case short code                              | `loyalty_tier`  |
| `{Entity}`          | PascalCase entity name                             | `Order`         |
| `{entity}`          | snake_case entity name                             | `order_item`    |
| `{Vendor}_{Module}` | Magento module identifier                          | `Acme_OrderExport` |

## Deprecated / aliased placeholders

| Old token          | Treat as       | Action          |
|--------------------|----------------|-----------------|
| `{ModuleName}`     | `{Module}`     | Substitute as `{Module}`. New templates SHOULD NOT introduce `{ModuleName}`. |
| `{VendorName}`     | `{Vendor}`     | Substitute as `{Vendor}`. |

Both aliases are kept so existing templates keep working, but the template-lint script
warns on new uses.

## Substitution rules

- Substitution is whole-token: replace the literal text `{Vendor}` with the resolved
  value. No regex on naked identifiers.
- After substitution, the resulting file must pass `php -l` / `xmllint` / `node --check`
  as applicable. The template-lint fixture is responsible for verifying this.
- An unsubstituted placeholder left in a generated file is a hard error.

## How the template-lint script enforces this

```
# Pseudo-code
ALLOWED = {Vendor, vendor, Module, module, AttributeCode, attribute_code,
           Code, code, Entity, entity, Attribute Label, ...}
for each templates/**/* file:
    for each {Token} occurrence:
        if Token not in ALLOWED:
            fail
    substitute with fixture values
    verify with php -l / xmllint / node --check
```
