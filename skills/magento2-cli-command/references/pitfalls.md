# Common Pitfalls — CLI Commands and Cron Jobs

## 1. Business logic in the command or cron class

**Pitfall:** putting SQL queries, API calls, or complex transformations directly in
`execute()` of the command or cron class.

**Why it matters:** the class becomes untestable without a full Magento bootstrap; any
logic change also requires a command-level integration test.

**Fix:** move all business logic to a service class (`{ServiceName}`) that is injected
via the constructor. The command/cron `execute()` only: reads input, calls the service,
handles exceptions, and returns/outputs a result.

---

## 2. Bare integer return codes in commands

**Pitfall:** `return 0;` or `return 1;` in the `execute()` method.

**Fix:** use `Magento\Framework\Console\Cli::RETURN_SUCCESS` and
`Magento\Framework\Console\Cli::RETURN_FAILURE`. The PHPCS Magento2 standard flags bare
literals in this position.

---

## 3. Area code set too late or set twice

**Pitfall:** calling `$state->setAreaCode('frontend')` inside a service that is also
invoked from a controller (where the area is already set). The second call throws
`\Magento\Framework\Exception\LocalizedException`.

**Fix:** check `$state->getAreaCode()` first, or set the area only in command-level
bootstrap (before delegating to the service). Alternatively, inject
`\Magento\Framework\App\State` only into the command class, not the service, and pass the
resolved area-specific data as parameters.

---

## 4. Non-idempotent cron jobs

**Pitfall:** a cron job that inserts a new row on every run instead of upserting, or
sends duplicate emails if the schedule fires twice (due to clock skew or a manual
`cron:run`).

**Fix:** design the service method so that running it N times produces the same result as
running it once. Common patterns:
- Query for unprocessed records (status-flagged) and mark them processed.
- Use `INSERT … ON DUPLICATE KEY UPDATE` / `replace()`.
- Check a flag/sentinel before acting.

---

## 5. Overlapping long-running cron jobs

**Pitfall:** a slow job (> 1 minute) is still running when the scheduler fires the next
instance. Two processes corrupt shared state or cause duplicate work.

**Fix:** acquire a named lock at the start (e.g. via
`Magento\Framework\Lock\LockManagerInterface`) and release it in a `finally` block.
Return early (silently) if the lock is unavailable.

---

## 6. No output for long-running commands

**Pitfall:** a command that processes thousands of records with no visible progress.
Users or CI pipelines assume it hung.

**Fix:** write periodic progress to `$output->writeln()` (e.g. every 100 records) or use
Symfony's `ProgressBar` helper:

```php
$bar = new \Symfony\Component\Console\Helper\ProgressBar($output, $totalCount);
$bar->start();
foreach ($items as $item) {
    $this->service->processItem($item);
    $bar->advance();
}
$bar->finish();
$output->writeln('');
```

---

## 7. `$name` constructor parameter omitted

**Pitfall:** forgetting to pass `$name = null` and call `parent::__construct($name)`.
Symfony's `Command` base constructor must receive the command name (or it reads it from
`configure()`). Without `parent::__construct()`, the command is never initialized.

**Fix:** always declare `string $name = null` as the last constructor parameter and call
`parent::__construct($name)` before anything else. The DI container passes `null`;
`configure()` then calls `setName()`.

---

## 8. Cron job registered in global `di.xml` instead of `crontab.xml`

**Pitfall:** some developers wire cron jobs in `di.xml` using virtual types, instead of
the proper `crontab.xml` declaration.

**Fix:** always use `etc/crontab.xml`. `di.xml` is the correct place for `CommandList`
registration (console commands), not for cron jobs.
