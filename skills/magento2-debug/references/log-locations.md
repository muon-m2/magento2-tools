# Log Locations

Canonical reference for Magento 2 log paths and how to read them. Shared by
`magento2-debug` and `magento2-bug-fix` (bug-fix's `log-targets.md` points here). Resolve
relative paths against `{ctx.magento_root}`.

## Magento Core

| Path                         | Contents                                      |
|------------------------------|-----------------------------------------------|
| `var/log/system.log`         | Psr-Logger output (info / notice / warning)   |
| `var/log/exception.log`      | Uncaught exceptions, fatal errors             |
| `var/log/debug.log`          | All levels when `developer/debug/debug_logging = 1` |
| `var/log/cron.log`           | Cron worker activity                          |
| `var/log/payment.log`        | Payment integrations when payment debug is on |
| `var/log/support_report.log` | Adobe Commerce support tool output            |
| `var/report/{hash}`          | Frontend exception reports (`Magento_ErrorHandler`) |

(There is no standard `var/log/connection.log` in core Magento — a module may create one,
but don't assume it exists.)

## Custom Module

Modules registering Monolog stream handlers typically write to:

- `var/log/{vendor}_{module}.log`
- `var/log/{module}.log`

Find the exact path via `grep -rE 'StreamHandler' {ctx.magento_root}/app/code/{Vendor}/{Module}/`
(look for the file path passed to `new StreamHandler(...)` in DI or the logger virtualType).

## Container / Infrastructure

| Path                                | Contents                                                  |
|-------------------------------------|-----------------------------------------------------------|
| `/var/log/nginx/error.log` (host)   | Reverse-proxy errors, 502s, upstream timeouts             |
| `/var/log/php-fpm/error.log` (host) | PHP-FPM worker errors                                     |
| `docker compose logs php`           | Container stdout — captures everything if not redirected  |
| `docker compose logs mysql`         | DB errors (deadlocks, slow queries when slow log enabled) |
| `docker compose logs rabbitmq`      | Queue consumer errors                                     |
| `docker compose logs redis`         | Cache layer errors                                        |

## Reading via Runner

Prepend `{ctx.runner}` when the logs live inside a container:

```
{ctx.runner} tail -n 200 var/log/exception.log
{ctx.runner} grep -E "MyVendor_MyModule" var/log/system.log
```

## Time Windows

Grep with `--since` when the tool supports it; otherwise use `tail -n` heuristics:

| Recency      | Approach                                  |
|--------------|-------------------------------------------|
| Last minute  | `tail -n 200 var/log/exception.log`       |
| Last hour    | `tail -n 5000` or `awk '$1 >= "{HH:MM}"'` |
| Last day     | full file scan, group by signature        |
| Since deploy | `awk '$1 " " $2 >= "{deploy_timestamp}"'` |

## Grep Patterns by Symptom

| Symptom                  | Pattern                                                                        |
|--------------------------|--------------------------------------------------------------------------------|
| 500 error / white screen | `grep -E "Fatal\|Exception\|TypeError" var/log/exception.log`                  |
| Slow page                | `grep -E "took [0-9]{4,}ms" var/log/system.log` (if a profiler logs durations) |
| Queue stuck              | `grep -E "consumer\|queue\|amqp" var/log/system.log`                           |
| Cron not running         | `grep -E "cron\|crontab" var/log/cron.log`                                     |
| Cache mishit             | `grep -E "cache\|getKey\|getIdentities" var/log/debug.log`                     |
| Payment failure          | `grep -E "gateway\|capture\|authorize" var/log/payment.log`                    |

## Log Rotation

If a log appears empty, look for `*.log.1` or `*.gz` siblings before concluding "no
entries". Magento does **not** rotate its own logs by default; OS-level logrotate may have
moved recent entries. (There is no `dev:di:info`-style log-truncation job — that command
reports DI info and has nothing to do with logs.)

## What to Save

For each log file searched, record (in the consuming skill's collect/snapshot artefact —
e.g. bug-fix saves to `.docs/bug-fixes/{slug}/collect.md`):

- Path searched
- Pattern used
- Match count
- 3–5 sample matches with timestamps

Do not paste raw log dumps into the conversation — group by error signature and surface the
top distinct entries.
