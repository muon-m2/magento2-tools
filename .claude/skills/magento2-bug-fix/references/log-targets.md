# Magento 2 Log Targets

Default log paths grep'd during Phase 1. Resolve against `{ctx.magento_root}`.

## Core Magento Logs

| Path | Contents |
|------|---------|
| `var/log/system.log` | Catch-all info/notice/warn from `Psr\Log\LoggerInterface` |
| `var/log/exception.log` | Uncaught exceptions, fatal errors |
| `var/log/debug.log` | When `developer/debug/debug_logging = 1`, all log levels |
| `var/log/cron.log` | Cron job execution; depends on `bin/magento setup:config:set` |
| `var/log/payment.log` | Payment integrations (Magento writes here when payment debug on) |
| `var/log/connection.log` | Composer / Marketplace / authentication errors |
| `var/log/support_report.log` | Adobe Commerce Support Report tool output |
| `var/report/{hash}` | Frontend exception reports (Magento_ErrorHandler) |

## Custom Module Logs

Modules registering their own Monolog handler typically write to `var/log/{vendor}_{module}.log`
or `var/log/{module}.log`. Grep for `addHandler(.*StreamHandler` in module DI to find the
exact path.

## Container / Infrastructure Logs

| Path | Contents |
|------|---------|
| `/var/log/nginx/error.log` (host) | Reverse proxy errors, 502s, upstream timeouts |
| `/var/log/php-fpm/error.log` (host) | PHP-FPM worker errors |
| `docker compose logs php` | Container stdout — captures everything if not redirected |
| `docker compose logs mysql` | DB errors (deadlocks, slow queries when slow log enabled) |
| `docker compose logs rabbitmq` | Queue consumer errors |
| `docker compose logs redis` | Cache layer errors |

## Time Windows

Grep with `--since` when the tool supports it; otherwise use `tail -n` heuristics:

| Symptom recency | Approach |
|-----------------|----------|
| Seen in last minute | `tail -n 200 var/log/exception.log` |
| Seen in last hour | `tail -n 5000` or `awk '$1 >= "{HH:MM}"'` |
| Seen in last day | Full file scan, group by signature |
| Seen since deploy | `awk '$1 " " $2 >= "{deploy timestamp}"'` |

## Grep Patterns by Symptom

| Symptom | Pattern |
|---------|---------|
| 500 error / white screen | `grep -E "Fatal|Exception|TypeError" var/log/exception.log` |
| Slow page | `grep -E "took [0-9]{4,}ms" var/log/system.log` (if profiler logs) |
| Queue stuck | `grep -E "consumer|queue|amqp" var/log/system.log` |
| Cron not running | `grep -E "cron|crontab" var/log/cron.log` |
| Cache mishit | `grep -E "cache|getKey|getIdentities" var/log/debug.log` |
| Payment failure | `grep -E "gateway|capture|authorize" var/log/payment.log` |

## Log Cleanup

Magento truncates logs via the `dev:di:info` style maintenance jobs. If a log is empty,
check if it has been recently rotated — look for `var/log/system.log.1` or `*.gz` sibling
files before concluding "no log entries."

## Reading via Runner

When `{ctx.runner}` is a Docker exec prefix, prepend it:

```
{ctx.runner} tail -n 200 var/log/exception.log
{ctx.runner} grep -E "MyVendor_MyModule" var/log/system.log
```

## What to Save

For each log file searched, save to `.docs/bug-fixes/{slug}/collect.md`:
- Path searched
- Pattern used
- Match count
- 3-5 sample matches with timestamps

Do not paste raw log dumps into the conversation — group by error signature and surface
the top distinct entries.
