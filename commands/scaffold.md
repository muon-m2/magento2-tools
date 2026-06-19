---
description: Entry point for Magento 2 code generation — routes to the right generator skill starting with magento2-module-create, which in turn delegates to specialist generators.
argument-hint: "[<type>] [<Vendor>_<Module>] [--flags]"
---
Use the `magento2-tools:magento2-module-create` skill, forwarding these arguments verbatim: $ARGUMENTS

The module-create skill is the canonical scaffold entry point. Depending on what you need to generate, it will guide you to the appropriate specialist generator:

- extension-point (magento2-extension-point)
- system-config (magento2-system-config)
- cli-command (magento2-cli-command)
- message-queue (magento2-message-queue)
- eav-attribute (magento2-eav-attribute)
- graphql-create (magento2-graphql-create)
- webapi-create (magento2-webapi-create)
- frontend-create (magento2-frontend-create)
- adminhtml-form (magento2-adminhtml-form)
- adminhtml-listing (magento2-adminhtml-listing)
