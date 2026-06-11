# {ModuleName}

{One paragraph describing what this module does and why it exists.}

## Features

- {Feature one}
- {Feature two}

## Installation

```bash
bin/magento module:enable {Vendor}_{ModuleName}
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento cache:flush
```

<!-- When persistence surface is declared, add: -->
<!--
After `setup:upgrade`, regenerate the declarative schema whitelist:

```bash
bin/magento setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleName}
```
-->

## Configuration

Navigate to **Stores → Configuration → {Section} → {Group}**.

| Field        | Description   | Default         |
|--------------|---------------|-----------------|
| {Field name} | {Description} | {Default value} |

<!-- Omit this section if the module has no admin configuration. -->

## Public API

<!-- Include when rest_api or graphql surface is declared. -->

| Interface                                                   | Description   |
|-------------------------------------------------------------|---------------|
| `{Vendor}\{ModuleName}\Api\{EntityName}RepositoryInterface` | {Description} |

## Dependencies

| Module              | Purpose        |
|---------------------|----------------|
| `Magento_Framework` | Core framework |

## Known Limitations

- {Any intentional constraint or out-of-scope behavior. Remove this section if none.}
