# Xdebug Troubleshooting

The `xdebug` mode verifies Xdebug configuration and surfaces common issues.

## Checklist

### 1. Xdebug installed

```bash
{ctx.runner} php -m | grep -i xdebug
```

If empty: Xdebug is not loaded. Install via the project's image build (PECL or PHP-FPM
config). Do not edit `/etc/php/conf.d` ad-hoc.

### 2. Xdebug mode

```bash
{ctx.runner} php -r 'echo ini_get("xdebug.mode");'
```

Common modes:

- `develop,debug` — full step-through debugging
- `coverage` — code coverage measurement
- `develop,debug,profile` — also Cachegrind profiling

Set via `php.ini`:

```
xdebug.mode=develop,debug
```

### 3. Client connection

```bash
{ctx.runner} php -r 'echo ini_get("xdebug.client_host");'
{ctx.runner} php -r 'echo ini_get("xdebug.client_port");'
```

- `client_host`: usually `host.docker.internal` for Docker on Mac/Windows, or the host's
  Docker bridge IP on Linux.
- `client_port`: 9003 by default (changed from 9000 in Xdebug 3).

### 4. IDE listening

The IDE must listen on the configured port:

- PhpStorm: green telephone icon "Start Listening for PHP Debug Connections."
- VSCode: launch config `port: 9003`.

### 5. Path mapping

The container and host file paths differ. Configure path mapping in the IDE:

- Container: `/var/www/html/src/app/code/Acme/Module`
- Host: `~/projects/example/src/app/code/Acme/Module`

PhpStorm: Settings → Languages → PHP → Servers → add mapping.

## Common Issues

| Symptom                        | Likely cause                                      |
|--------------------------------|---------------------------------------------------|
| Breakpoint never hits          | `XDEBUG_TRIGGER` cookie/header not set on request |
| "Cannot find source file"      | Path mapping wrong                                |
| Connection refused             | IDE not listening; or wrong port                  |
| Slow page when Xdebug on       | Use `xdebug.mode=off` when not debugging          |
| Step-into shows generated code | Path mapping excludes `generated/` directory      |

## Toggling Xdebug

Some projects have a Makefile target:

```bash
make xdebug-on
make xdebug-off
```

Check `Makefile` for `xdebug-on:` and `xdebug-off:` rules. If present, prefer them over
editing `php.ini` directly.

## Coverage Mode

For PHPUnit coverage:

```bash
{ctx.runner} XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-clover var/log/coverage.xml
```

Don't enable coverage globally — it slows non-coverage runs.

## Production

Xdebug must NOT be installed in production. The skill flags it as a Critical finding if
detected on a production-mode install. Use `mode=production` for performance.
