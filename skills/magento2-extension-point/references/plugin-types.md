# Plugin Types — Before / After / Around

Magento 2 plugins (interceptors) hook into public, non-final, non-static methods via a
generated proxy class. Three types exist; choose the lightest one that expresses the intent.

## Before Plugin

Runs **before** the original method. Can modify the incoming arguments.

```php
public function beforeMethodName(
    SubjectClass $subject,
    ArgType $arg1,
): ?array {
    // Return a single modified arg, or an array of modified args.
    // Return null to leave args unchanged (PHP 8 idiom).
    return [$modifiedArg1];
}
```

- **Return value:** `?array` — an array of replacement positional arguments, or `null`
  to pass originals through unchanged.
- **Cannot** change what the method returns.
- Runs even if the method throws.

## After Plugin

Runs **after** the original method (and after all `around` wrappers). Can modify the
return value.

```php
public function afterMethodName(
    SubjectClass $subject,
    ReturnType $result,
    ArgType $arg1,
): ReturnType {
    // $result is what the original (or around) returned.
    return $result; // or a modified version
}
```

- **Return value:** must be the same type as the original return (or a subtype).
- Receives the original arguments after `$result` so you can branch on them.
- Cannot modify arguments passed to the next interceptor.

## Around Plugin

Wraps the entire call chain. Use **only** when before/after cannot express the logic
(e.g. you need to suppress the call, change control flow, or guard exceptions around
`$proceed`).

```php
public function aroundMethodName(
    SubjectClass $subject,
    callable $proceed,
    ArgType $arg1,
): ReturnType {
    // Optionally transform $arg1, then call $proceed
    $result = $proceed($arg1);
    // Optionally transform $result
    return $result;
}
```

- **`$proceed`** is the next interceptor in the chain (or the real method). Skipping
  `$proceed()` suppresses the original call and all downstream interceptors — a
  significant side-effect.
- Around plugins are expensive: each one adds a call-stack frame on every invocation of
  the original method, even when your guard condition is false.
- Never wrap `$proceed` in a `try/catch` that swallows exceptions without re-throwing.

## SortOrder

`sortOrder` in `di.xml` controls the execution order when multiple plugins intercept
the same method:

- **Before plugins:** lower sortOrder runs first (modifying args first).
- **After plugins:** lower sortOrder runs last (closest to the caller, sees the most
  final result).
- **Around plugins:** lower sortOrder wraps outermost.

Default `sortOrder` for new plugins: `10`. Leave gaps (10, 20, 30…) to let future
plugins interleave without renumbering.

## Quick Decision Guide

| Need | Choose |
|------|--------|
| Modify input arguments | `before` |
| Modify return value | `after` |
| Both, independently | `before` + `after` |
| Suppress the original call | `around` (justify in code comment) |
| Guard with try/catch around the call | `around` (justify in code comment) |
| Conditional call / alternate path | `around` (justify in code comment) |
