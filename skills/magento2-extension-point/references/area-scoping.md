# Area Scoping — di.xml and events.xml

Magento 2 loads configuration files per-area. Narrow the scope to the smallest area
that satisfies the requirement — this avoids side-effects in unrelated areas and makes
the intent explicit.

## Available Areas

| Area folder | When active |
|-------------|-------------|
| `etc/` (global) | All areas — loaded first, then merged with area overrides |
| `etc/frontend/` | Storefront web requests (`\Magento\Framework\App\Area::AREA_FRONTEND`) |
| `etc/adminhtml/` | Admin panel web requests (`\Magento\Framework\App\Area::AREA_ADMINHTML`) |
| `etc/webapi_rest/` | REST API requests (`rest/`) |
| `etc/webapi_soap/` | SOAP API requests (`soap/`) |
| `etc/graphql/` | GraphQL requests (`graphql`) |
| `etc/crontab/` | Cron job execution |

## Which File to Use

### Plugin / Preference in di.xml

| Goal | File |
|------|------|
| Plugin must apply in every area (e.g., a repository plugin) | `etc/di.xml` |
| Plugin needed only on storefront (e.g., cart display logic) | `etc/frontend/di.xml` |
| Plugin needed only in admin (e.g., admin grid logic) | `etc/adminhtml/di.xml` |
| Plugin needed only on REST API calls | `etc/webapi_rest/di.xml` |
| Plugin needed only on GraphQL | `etc/graphql/di.xml` |
| Plugin needed only on cron | `etc/crontab/di.xml` |

### Observer in events.xml

| Goal | File |
|------|------|
| Observer must fire in every area | `etc/events.xml` |
| Observer only for storefront events | `etc/frontend/events.xml` |
| Observer only for admin events | `etc/adminhtml/events.xml` |
| Observer only for REST events | `etc/webapi_rest/events.xml` |
| Observer only for cron events | `etc/crontab/events.xml` |

## Merge Behaviour

Area-specific files **merge** with the global file — they do not replace it. A plugin
declared in `etc/di.xml` is active in all areas. A plugin declared in
`etc/frontend/di.xml` is active in `frontend` only.

If you declare the same plugin name in both `etc/di.xml` and `etc/frontend/di.xml`,
the area-specific declaration wins for the `frontend` area (it merges by plugin
`name` attribute, with the more-specific file taking precedence).

## Common Pitfalls

- **Global when you mean frontend:** a plugin in `etc/di.xml` that modifies storefront
  rendering will also fire during cron jobs and REST calls — potentially wasting CPU.
- **Frontend when you mean all web:** `frontend` does NOT include `adminhtml` — if
  an admin page needs the same plugin, declare it in `etc/di.xml` or also in
  `etc/adminhtml/di.xml`.
- **Missing area means silent non-firing:** an observer in `etc/adminhtml/events.xml`
  will NOT fire on storefront requests, even if the event is dispatched there.

## Example: Narrowing a Plugin to REST Only

```xml
<!-- etc/webapi_rest/di.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:ObjectManager/etc/config.xsd">
    <type name="Magento\Catalog\Api\ProductRepositoryInterface">
        <plugin name="acme_catalog_api_product_enrich"
                type="Acme\Catalog\Plugin\Api\ProductRepositoryPlugin"
                sortOrder="10"/>
    </type>
</config>
```
