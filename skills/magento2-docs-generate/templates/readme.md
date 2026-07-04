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

<!-- Declarative-schema modules only (module declares `db_schema.xml`) — omit this
     paragraph and command entirely when the module has no `db_schema.xml`, following the
     same "omit when the surface is absent" rule as the Features/Configuration/Public API
     sections below. -->
This module declares a declarative schema. After `setup:upgrade`, regenerate the schema
whitelist so future schema changes are detected correctly:

    bin/magento setup:db-declaration:generate-whitelist --module-name={Vendor}_{Module}

## Dependencies

{DEPENDENCIES_LIST}

## Features

{FEATURES_LIST}

## Configuration

{CONFIG_TABLE}

## Public API

{PUBLIC_API_TABLE}

## Known Limitations

{KNOWN_LIMITATIONS}

## Documentation

{DOCUMENTATION_LINKS}
