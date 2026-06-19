# {Vendor}_{Module}

{MODULE_DESCRIPTION}

## Requirements

- Magento Open Source or Adobe Commerce (see `composer.json` for version constraints)
- PHP (see `composer.json` for version constraints)

## Installation

Enable the module and run setup upgrade:

    bin/magento module:enable {Vendor}_{Module}
    bin/magento setup:upgrade
    bin/magento cache:flush

## Dependencies

{DEPENDENCIES_LIST}

## Documentation

Full technical reference, including public API surface, events, plugins, REST routes,
GraphQL types, database schema, and configuration paths:

[docs/technical-reference.md](docs/technical-reference.md)
