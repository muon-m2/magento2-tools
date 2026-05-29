# Common Magento Events

A curated list of high-traffic events likely to be the target of a `trace` query.

## Checkout

- `checkout_cart_save_after`
- `checkout_submit_all_after`
- `checkout_submit_before`
- `sales_quote_collect_totals_before`
- `sales_quote_save_after`
- `sales_quote_address_collect_totals_after`

## Order

- `sales_order_place_before`
- `sales_order_place_after`
- `sales_order_save_after`
- `sales_order_state_change_before`
- `sales_order_payment_capture`

## Catalog

- `catalog_product_save_before`
- `catalog_product_save_after`
- `catalog_product_load_after`
- `catalog_category_save_after`
- `catalog_product_collection_load_after`

## Customer

- `customer_register_success`
- `customer_login`
- `customer_save_after`
- `customer_account_create`
- `customer_address_save_after`

## Frontend

- `controller_action_predispatch`
- `controller_action_postdispatch`
- `cms_page_render`
- `layout_render_before`

## Admin

- `admin_user_authenticate_after`
- `admin_session_user_login_success`

## How to Find Observers

```bash
grep -rE '<event\s+name="{event_name}"' src/app/code/*/etc vendor/*/*/etc 2>/dev/null
```

Or via `${CLAUDE_SKILL_DIR}/scripts/plugin-trace.sh --event={event_name}`.

## Performance Hot Spots

Events fired per-page-load on storefront critical path:

- `controller_action_predispatch_*`
- `cms_page_render` (every CMS page)
- `catalog_product_collection_load_after` (every listing)

An observer with > 10ms work registered on these events is a finding for
`magento2-performance-audit`.

## Anti-Patterns

- Observers that mutate the event object (other observers see the change).
- Observers that throw — Magento swallows the exception and logs it; the action still
  runs.
- Observers performing DB writes — should be queue-based for anything > 100ms.
