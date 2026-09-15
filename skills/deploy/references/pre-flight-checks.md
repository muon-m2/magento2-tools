# Pre-Flight Checks

State-free checks run before any deploy command. Failure of a Required check aborts the
deploy. Failure of an Optional check is logged and continues.

## Required (All Environments)

### Module registration

Resolve each supplied module's directory once, then run this and every later per-module check
against it. First hit wins:

1. `{module_dir}/{Vendor}/{Module}` (`src/app/code` or `app/code`);
2. the installed package whose `etc/module.xml` declares it — `vendor/*/*/etc/module.xml` or
   `vendor/*/*/src/etc/module.xml`;
3. a working copy — `dev-packages/*/etc/module.xml` or `dev-packages/*/src/etc/module.xml`.

Match the **top-level** `<module name>` only: a package whose `<sequence>` merely names the module
is not that module. Record which location resolved in the check note. Looking under `app/code`
alone failed every Composer-installed module as "missing registration.php" — and, through
`deploy --validate-only`, its `release` validation too.

```bash
test -f {resolved_module_dir}/registration.php \
    || { echo "missing registration.php for $m"; exit 1; }
```

### composer.json validity

```bash
for m in {modules}; do
    {runner} composer validate --no-check-publish {resolved_module_dir}/composer.json
done
```

### Module dependency graph well-formed

Parse every `<sequence>` block in `etc/module.xml`. Ensure no cycles and that every
referenced module exists: under `app/code`, as the declared `<module name>` of a `vendor/` or
`dev-packages/` package (the same lookup as *Module registration*), or as a `composer.lock` entry.
`Magento_*` targets always count as present. Do not rely on `composer.lock` alone — it names
packages (`acme/module-file-attachment`), not modules (`Acme_FileAttachment`), and almost no
package sets `extra.magento.module-name`.

### Unit tests

```bash
{runner} vendor/bin/phpunit {modules-test-unit-paths}
```

Required: all tests pass. Skipped/incomplete are allowed but reported.

### Magento DB state

```bash
{magento_cli} setup:db:status
```

Required: exit code 0. If "Schema is up to date" — pass. If "needs upgrade" but not from
the modules being deployed — alarm but pass (it's a pre-existing state). If "needs
upgrade" from a module in the deploy list — pass (that's exactly what we're about to do).

### Disk space

```bash
df -h $(pwd) | awk 'NR==2 {print $4}'
```

Required: ≥ 1GB free for non-production, ≥ 5GB free for production.

## Required (Production Only)

### Git working tree clean

```bash
git status --porcelain
```

Required: empty output. Any uncommitted changes abort the deploy.

### Composer install dry-run

```bash
{runner} composer install --no-dev --dry-run
```

Required: exit code 0 AND no "would install" entries (state matches lock file).

### Branch matches production target

```bash
git rev-parse --abbrev-ref HEAD
```

Required: matches the project's production branch (typically `main` or `release/*`).

### Maintenance mode availability

Check that the deploy account can write to `var/.maintenance.flag`. If not, maintenance
mode cannot be toggled — abort with clear message.

## Optional (Run if Tools Present)

### PHPCS Magento2 standard

```bash
{runner} vendor/bin/phpcs --standard=Magento2 {modules-paths}
```

Required when `--strict`. Default: optional.

### PHPStan level 8

```bash
{runner} vendor/bin/phpstan analyse --level=8 {modules-paths}
```

Required when `--strict`. Default: optional.

### PHPMD

```bash
{runner} vendor/bin/phpmd {modules-paths} text phpmd.xml
```

Always optional.

### Rector dry-run

```bash
{runner} vendor/bin/rector process --dry-run {modules-paths}
```

Always optional. Useful pre-upgrade to verify no required fixes are pending.

### Composer audit

```bash
{runner} composer audit --format=json
```

Optional. Warn if any High or Critical severity advisory matches a declared dependency.

## Reporting Pre-Flight Results

Emit to `.docs/deployments/{ts}-{env}-preflight.json`:

```json
{
  "preflight": {
    "passed": true,
    "checks": [
      {"name": "module-registration", "required": true, "result": "pass", "duration_ms": 12},
      {"name": "composer-validate", "required": true, "result": "pass", "duration_ms": 340},
      {"name": "unit-tests", "required": true, "result": "pass", "duration_ms": 8420, "details": "42 tests, 0 failures"},
      {"name": "phpcs", "required": false, "result": "skipped", "reason": "--strict not set"}
    ]
  }
}
```

## Failure Behaviour

A failed Required check aborts the deploy WITHOUT running anything destructive. The
report includes:

- Which checks ran
- Which failed
- Exact output of the failing check (truncated to 2000 chars)
- Suggested remediation (link to a doc when possible)

The user fixes the issue and re-runs `/deploy` from the top — there is no
"resume from check N" mode.
