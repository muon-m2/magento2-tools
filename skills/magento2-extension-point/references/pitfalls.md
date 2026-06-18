# Common Pitfalls

Known mistakes when wiring extension points. Phase 4 of the skill checks for these;
`magento2-module-review --diff` catches many at the linting gate.

## Plugin Pitfalls

### Plugging a `final` Method

Magento's interceptor generator skips `final` methods and generates a proxy that does
NOT intercept the call. No error is thrown — the plugin silently does nothing.

**Fix:** use a preference (if you own the module or must change the logic) or find an
event dispatched nearby.

### Plugging a `private` or `static` Method

Interceptors are generated via a proxy subclass. `private` methods are not visible to
the subclass; `static` methods bypass the instance entirely. Neither can be intercepted.

**Fix:** request an event, or — if you own the target — refactor to a `protected` method
and add your plugin.

### Plugging a Data Interface

`Api/Data/*Interface` classes are generated (data objects). Their generated
implementations often lack the usual class proxy structure, causing fatal errors or
silent non-interception.

**Fix:** plugin the concrete repository or service layer, not the data interface.

### Overusing `around`

Every `around` plugin adds a call-stack frame on **every** invocation, even when your
guard condition is `false`. On high-traffic methods (product load, cart calculate, price
render) this accumulates measurably.

**Rule:** use `around` only when `before` + `after` genuinely cannot express the logic.
Add a comment explaining why `around` was chosen.

### Skipping `$proceed` in `around`

Calling an `around` plugin without invoking `$proceed()` suppresses the original method
**and every downstream interceptor**. This is almost always unintentional and breaks
other extensions.

**Fix:** always call `$proceed()` unless suppressing the call is the explicit
purpose (and even then, document it).

## Observer Pitfalls

### Non-Idempotent Observer

If the same event fires multiple times per request (e.g. during bulk import), a
non-idempotent observer will apply its effect multiple times. Use a guard variable or
check the entity state before acting.

### Database Writes in Hot Events

Events like `catalog_product_load_after` or `catalog_product_collection_load_after`
fire for every product in a collection. A DB write inside such an observer causes
N queries per page load.

**Rule:** never write to the database inside events that fire proportional to a
collection size. Defer with a queue message or accumulate in memory.

### Wrong Area in events.xml

An observer in `etc/adminhtml/events.xml` does NOT fire on storefront requests, even
if the same event is dispatched there. Use `etc/events.xml` for cross-area observers.

## Preference Pitfalls

### Two Modules Preferring the Same Interface

Only one preference wins per interface per area. Magento uses whichever module is loaded
last (via `sequence` in `module.xml`). The losing module's customisation is dropped
silently.

**Mitigation:** use a plugin on the concrete class whenever possible so both modules'
logic composes. If you must use a preference, document the conflict risk in the report.

### Preference on a Concrete Class Instead of an Interface

Preferring `Magento\Catalog\Model\Product` when the consumer type-hints
`ProductInterface` means Magento resolves `ProductInterface` to its own concrete class,
not yours. Your preference is never used.

**Fix:** prefer the interface the consuming code type-hints against. Check with
`bin/magento dev:di:info 'Magento\Catalog\Api\ProductRepositoryInterface'`.
