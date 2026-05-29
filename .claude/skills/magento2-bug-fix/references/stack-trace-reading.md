# Reading a Magento 2 Stack Trace

Magento stack traces include several frame types that aren't obvious to a generic reader.
Use this guide to triage frames quickly.

## Frame Types

### Interceptor (Plugin) Frames

```
#5 Magento\Catalog\Model\Product\Interceptor->save() called at [generated/code/Magento/Catalog/Model/Product/Interceptor.php:N]
```

`*\Interceptor` indicates that one or more plugins intercept that method. The interceptor
class is auto-generated under `generated/code/`. To find the plugins:

```
grep -rE 'type=.*Product.*->save|name=.*save' app/code/*/etc/di.xml
```

Or query the DI graph via `magento2-debug trace --method='Magento\Catalog\Model\Product::save'`.

### Proxy Frames

```
Magento\Customer\Model\Customer\Proxy->getId()
```

A Proxy is a lazy wrapper. The actual class is `Magento\Customer\Model\Customer` — the
Proxy delegates after first invocation. Bugs in proxies are almost always bugs in the
underlying class.

### Factory Frames

```
Magento\Catalog\Model\ProductFactory->create()
```

Factories instantiate a class with all dependencies injected. A bug in a factory frame
means the class being created has a constructor problem.

### Observer Frames

```
Magento\Framework\Event\Manager->dispatch('checkout_submit_all_after')
```

Look at `etc/events.xml` files for all observers on that event. Each observer is a
separate code path; the failure may be in any of them.

### Closure / Anonymous Frames

```
#10 Closure->{closure}() in vendor/magento/framework/...
```

Usually inside `array_map`, `array_walk`, or `Magento\Framework\Pipeline\State`. The
closure's source line is the actual logic.

## Reading Order

Read the stack trace **from the top frame down**. The top frame is the actual error site;
each frame below is the caller. The bug is usually at the top — but the *cause* may be
several frames down (a wrong argument passed by a caller).

## Finding the First Project-Owned Frame

Skip Magento core (`vendor/magento/`) and third-party (`vendor/*/`) frames to find the
first frame in `app/code/{Vendor}/`. That's typically where to start RCA.

```
grep -E "app/code/{Vendor}" stack_trace.txt | head -1
```

If no project frame exists, the bug is in Magento core or a third-party — the fix must go
in a project module (plugin/observer/preference). Do NOT edit `vendor/`.

## Git Blame for Suspicious Frames

```
git log -L {start},{end}:{file} | head -50
git blame -L {start},{end} {file}
```

Most useful when the failing line was added recently. If the line has been there for
years, the bug is likely upstream (a change in caller behaviour).

## When the Trace Lies

Some Magento errors swallow the inner stack:

- `Magento\Framework\Exception\LocalizedException` wraps a translated message and may not
  expose the original throwable. Look in `var/log/system.log` for the wrapped exception.
- `Mage\WebAPI\Exception` translates inner exceptions into HTTP responses; the inner trace
  is in `var/log/exception.log`, not in the response body.
- `Magento\Framework\Phrase` stringification can mask `__toString()` errors. Search for
  `Phrase::__toString` in the stack.

## Logging the Trace

When the user provides only the visible error, ask for:

```
{ctx.runner} grep -A 50 "{error signature}" var/log/exception.log
```

If logs don't have the trace, enable debug logging:

```
{ctx.magento_cli} setup:config:set --enable-debug-logging=true
```

Re-run the reproduction, capture, then disable debug logging:

```
{ctx.magento_cli} setup:config:set --enable-debug-logging=false
```

## Plugin Chain Inspection

When the failing method is intercepted by multiple plugins, the order of `before`,
`around`, `after` matters. Use:

```
{ctx.magento_cli} dev:di:info "Magento\Catalog\Model\Product"
```

This prints the resolved DI configuration including plugin sortOrder. Without the CLI,
walk every `di.xml` in `app/code/` and `vendor/*/*/etc/` for `<plugin>` entries on the
target class.
