# DI Graph Walk

## Files to Read

DI configuration lives in these files (per module + Magento core):

```
etc/di.xml                     # Global
etc/frontend/di.xml            # Frontend area
etc/adminhtml/di.xml           # Admin area
etc/webapi_rest/di.xml         # REST API area
etc/webapi_soap/di.xml         # SOAP API area
etc/graphql/di.xml             # GraphQL area
```

Read all of them for a complete picture; area-specific files override the global one.

## Resolving an Interface

For `Magento\Catalog\Api\ProductRepositoryInterface`:

1. Search every `di.xml` for `<preference for="Magento\Catalog\Api\ProductRepositoryInterface">`.
2. Multiple matches: the latest-loaded module wins. Magento's module loading order is
   defined by `<sequence>` blocks in `module.xml`.
3. Report all preferences found, with the winning one marked.

## Finding Plugins

For `Magento\Catalog\Model\Product`:

```bash
grep -rE '<type\s+name="Magento\\Catalog\\Model\\Product">' src/app/code/*/etc vendor/*/*/etc 2>/dev/null
```

Within each match, look for `<plugin name="..." type="..." sortOrder="..."/>`.

Sort plugins by `sortOrder` (ascending); within the same sortOrder, by alphabetical
plugin name.

For each plugin, find the actual method bindings:

- `beforeFoo()` → fires before `Foo`
- `aroundFoo()` → wraps `Foo`
- `afterFoo()` → fires after `Foo`

## Finding Arguments

For a constructor argument binding:

```xml
<type name="Magento\Catalog\Model\Product">
    <arguments>
        <argument name="someService" xsi:type="object">My\Replacement\Service</argument>
    </arguments>
</type>
```

The argument override may be in any di.xml. Find all of them; the winner is again the
last-loaded module.

## Output Format

```markdown
## DI Resolution: Magento\Catalog\Api\ProductRepositoryInterface

### Preferences (1 active, 0 overridden)

| Module | Implementation | Status |
|--------|---------------|--------|
| Magento_Catalog | Magento\Catalog\Model\ProductRepository | Active (default) |

### Plugins on Magento\Catalog\Model\ProductRepository

| sortOrder | Name | Class | Method | Type |
|-----------|------|-------|--------|------|
| 10 | acme_audit | Acme\Audit\Plugin\ProductRepositoryAuditPlugin | beforeSave | before |
| 20 | acme_export | Acme\OrderExport\Plugin\ProductRepositoryExportPlugin | afterSave | after |
| 30 | acme_metrics | Acme\Metrics\Plugin\ProductRepositoryMetricsPlugin | aroundSave | around |

### Argument Overrides

(none found)
```

## CLI Equivalent

When the CLI is available, the canonical answer is:

```
{ctx.magento_cli} dev:di:info "Magento\Catalog\Api\ProductRepositoryInterface"
```

This output is authoritative. Static analysis can diverge if the developer cache hasn't
been recompiled — note the limitation in the output.

## Useful Patterns

- "Why is this class being instantiated?" — walk preferences for the interface and any
  parent interfaces.
- "Why is this plugin running?" — search every di.xml for the plugin's class name.
- "Why is this NOT working?" — check `disabled="true"` on the plugin or
  `<preference>` declarations elsewhere.
