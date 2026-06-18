# Preference vs Plugin — Decision Matrix

Both plugins and preferences let you modify behaviour without editing the target class.
Choose the lightest mechanism that expresses the intent.

## Decision Matrix

| Scenario | Recommended | Why |
|----------|-------------|-----|
| Modify a public method's input or output | Plugin (before/after) | Non-invasive; other plugins still run |
| React to a domain event | Observer | Zero coupling to the target class |
| Suppress or radically change one method | Plugin (around) | Still composable with other plugins |
| Replace an **interface** binding for the whole app | Preference | Only correct way to swap a DI binding |
| Extend a concrete class and override several methods | Preference | Plugin can't override multiple methods cleanly |
| Target is `final` / method is `private` / `static` | Preference or event | Plugins can't intercept |
| Target dispatches an event you can hook | Observer | Lightest; doesn't touch the call stack |

## Why Preferences Are a Last Resort

A preference is a **wholesale replacement** of a DI binding. Problems:

1. **Conflict risk.** Two modules declaring a preference for the same type — only one
   wins (the last-loaded one). Plugins compose; preferences collide.
2. **Fragility on upgrade.** If the core class adds new methods, your preference class
   must implement them or PHP throws a fatal. Plugins are immune to this.
3. **Breaks other plugins.** Plugins on the original class may not apply to your
   replacement, depending on how the proxy is generated.
4. **Hidden override.** A preference is invisible to `bin/magento dev:di:info` as easily
   as plugins; developers may not realise the swap happened.

Use a preference when: you need to replace an **interface** binding (the only correct
mechanism), or when the target is `final` / private-method-only (plugins are physically
impossible).

## Preference vs Extension

If you only need to add methods (not replace existing ones), `__construct` injection or
a plugin is more appropriate. A preference that just adds methods and delegates
everything else bloats the DI graph for no reason.

## Conflict Resolution Example

Two modules both prefer `Magento\Catalog\Api\ProductRepositoryInterface`:

```
ModuleA: preference for="…Interface" type="ModuleA\Model\ProductRepository"
ModuleB: preference for="…Interface" type="ModuleB\Model\ProductRepository"
```

Only one is used — whichever module's `sequence` is declared last in the other's
`module.xml`. The losing module's override is silently dropped.

A plugin on `Magento\Catalog\Model\ProductRepository` (the concrete class) from both
modules would compose safely via `sortOrder`.

## Summary

```
observer < plugin (before/after) < plugin (around) < preference
```

Start at the left. Move right only when the leftward option is genuinely insufficient.
