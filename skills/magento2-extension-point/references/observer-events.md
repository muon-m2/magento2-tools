# Observer Events

Magento 2 dispatches events via `\Magento\Framework\Event\ManagerInterface::dispatch()`.
Observers listen in `etc/{area}/events.xml` and implement
`\Magento\Framework\Event\ObserverInterface`.

## Observer Class Structure

```php
use Magento\Framework\Event\Observer;
use Magento\Framework\Event\ObserverInterface;

class MyObserver implements ObserverInterface
{
    public function execute(Observer $observer): void
    {
        $event = $observer->getEvent();          // \Magento\Framework\Event
        $order = $event->getData('order');       // key matches dispatch() params
        // or: $observer->getData('order')       // shortcut — same data
    }
}
```

`$observer->getEvent()->getData('key')` and `$observer->getData('key')` are equivalent:
`getData` on the observer delegates to the event object.

## events.xml Structure

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:Event/etc/events.xsd">
    <event name="sales_order_save_after">
        <observer name="acme_module_track_order_save"
                  instance="Acme\Module\Observer\TrackOrderSave"/>
    </event>
</config>
```

Place in `etc/{area}/events.xml`. Use `etc/events.xml` for global scope.

## Area-Scoped events.xml

| Area folder | When to use |
|-------------|-------------|
| `etc/events.xml` | Observer must fire in every area |
| `etc/frontend/events.xml` | Storefront requests only |
| `etc/adminhtml/events.xml` | Admin panel requests only |
| `etc/webapi_rest/events.xml` | REST API requests only |
| `etc/crontab/events.xml` | Cron execution only |

## Common Dispatched Events

| Event | Payload keys | Notes |
|-------|-------------|-------|
| `sales_order_save_after` | `order` | After an order is saved |
| `sales_order_place_after` | `order` | After order placement |
| `checkout_cart_add_product_complete` | `product`, `request`, `response` | After add-to-cart |
| `catalog_product_save_after` | `product` | After product save in admin |
| `catalog_product_load_after` | `product` | After product load |
| `catalog_category_save_after` | `category` | After category save |
| `customer_save_after_data_object` | `customer_data_object`, `orig_customer_data_object` | After customer save |
| `controller_front_init_before` | `front` | Before front controller dispatch |
| `layout_load_before` | `layout`, `full_action_name` | Before layout load |
| `cms_page_render` | `page`, `controller_action`, `request` | After CMS page render |

For a full list, search the Magento core with:
```
grep -r "dispatch(" vendor/magento/ --include="*.php" | grep "'event_name'"
```

## Observer Naming Conventions

Observer names in `events.xml` must be unique per area. Use the pattern:
`{vendor_lower}_{module_lower}_{descriptive_snake}`.

Example: `acme_catalog_track_product_view`

Observer class names follow PascalCase: `TrackProductView`.
