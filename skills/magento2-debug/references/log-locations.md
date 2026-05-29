# Log Locations

Default paths and variations.

## Magento Core

| Path | Contents |
|------|---------|
| `var/log/system.log` | Psr-Logger output (info / notice / warning) |
| `var/log/exception.log` | Uncaught exceptions, fatal errors |
| `var/log/debug.log` | All levels when developer/debug_logging is on |
| `var/log/cron.log` | Cron worker activity |
| `var/log/payment.log` | Payment integrations when debug on |
| `var/log/connection.log` | Composer / Marketplace auth |
| `var/log/support_report.log` | Adobe Commerce support tool |
| `var/report/{hash}` | Frontend exception reports |

## Custom Module

Modules registering Monolog stream handlers typically write to:
- `var/log/{vendor}_{module}.log`
- `var/log/{module}.log`

Find via `grep -rE 'StreamHandler' app/code/{Vendor}/{Module}/etc/`.

## Container / Infrastructure

| Path | Contents |
|------|---------|
| `/var/log/nginx/error.log` | Reverse-proxy errors, 502s |
| `/var/log/php-fpm/error.log` | PHP-FPM worker errors |
| `docker compose logs php` | Container stdout |
| `docker compose logs mysql` | DB errors / deadlocks / slow queries |
| `docker compose logs rabbitmq` | Queue errors |
| `docker compose logs redis` | Cache layer errors |

## Reading via Runner

Prepend `{ctx.runner}` when reading container logs:

```
{ctx.runner} tail -n 200 var/log/exception.log
{ctx.runner} grep -E "MyVendor_MyModule" var/log/system.log
```

## Time Windows

| Recency | Approach |
|---------|----------|
| Last minute | `tail -n 200` |
| Last hour | `tail -n 5000` |
| Last day | full file scan, group by signature |
| Since deploy | `awk '$1 " " $2 >= "{deploy_timestamp}"'` |

## Log Rotation Hint

If a log appears empty, look for `*.log.1` or `*.gz` siblings. Magento doesn't rotate
its own logs by default; logrotate at the OS level may have moved recent entries.
