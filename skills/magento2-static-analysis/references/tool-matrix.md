# Static Analysis Tool Matrix

Which tool detects vs fixes what, and how to invoke each via `{ctx.runner}` and `{ctx.tools}`.

All commands below assume the tool path was resolved by `magento2-context` into `{ctx.tools}`.
Prefix with `{ctx.runner}` when running inside a Docker container (e.g.
`docker compose exec -T php vendor/bin/phpcs ...`).

## Tool Roles

| Tool | Role | Fixes code? | Config required? |
|------|------|-------------|-----------------|
| `phpcs` (Magento2 standard) | Detect coding-standard violations | No — use `phpcbf` | `--standard=Magento2` |
| `phpcbf` (Magento2 standard) | Auto-fix coding-standard violations | **Yes** | `--standard=Magento2` |
| `php-cs-fixer` | Auto-fix formatting (PER-CS baseline) | **Yes** | `.php-cs-fixer.dist.php` or built-in rules |
| `rector` `--dry-run` | Detect refactoring opportunities | No — use `rector process` | `rector.php` |
| `rector process` | Apply refactoring transforms (safe sets only) | **Yes** (gated) | `rector.php` |
| `phpmd` | Detect code-complexity, clean-code violations | No | `phpmd.xml` or built-in rule sets |
| `phpstan` | Detect type errors and dead-code paths | No | `phpstan.neon` or level flag |

## Detection Commands (read-only, Phase 2)

### phpcs — Detect

```bash
# Via runner (Docker):
{ctx.runner} {ctx.tools.phpcs} --standard=Magento2 --report=json --report-file={TMP}/phpcs.json {scope}

# Bare PHP:
{ctx.tools.phpcs} --standard=Magento2 --report=json --report-file={TMP}/phpcs.json {scope}
```

Exit code: 0 = no violations, 1 = violations found, 2 = runtime error.
`--report=json` produces machine-parseable output; map to findings schema (severity by
`type`: ERROR → high, WARNING → medium).

### phpstan — Detect

```bash
{ctx.runner} {ctx.tools.phpstan} analyse --error-format=json --no-progress {scope} \
    2>/dev/null > {TMP}/phpstan.json
```

Level: use `phpstan.neon`'s configured level; fall back to `--level=5` if no config exists.
phpstan is report-only — it produces no auto-fixable output. Map `level` to findings severity:
level 0–3 errors → high, level 4–6 → medium, level 7–8+ → low.

### phpmd — Detect

```bash
{ctx.runner} {ctx.tools.phpmd} {scope} json cleancode,codesize,controversial,design,naming,unusedcode \
    > {TMP}/phpmd.json
```

phpmd is report-only. Map `priority` (1-5) to severity: 1→critical, 2→high, 3→medium,
4→low, 5→info.

### rector — Dry Run (detect only)

```bash
{ctx.runner} {ctx.tools.rector} process --dry-run --output-format=json {scope} \
    > {TMP}/rector.json
```

Outputs a list of proposed transforms. Categorise each by the rector set it belongs to;
see `autofix-safety.md` for which sets are safe vs review-required.

## Fix Commands (auto-apply, Phase 3)

### phpcbf — Fix

```bash
{ctx.runner} {ctx.tools.phpcbf} --standard=Magento2 {scope}
```

Exit code: 0 = nothing to fix, 1 = fixes applied, 2 = runtime error.
Always exclude `vendor/` via `--ignore=*/vendor/*,*/generated/*,*/var/*`.

### php-cs-fixer — Fix

```bash
{ctx.runner} {ctx.tools.php_cs_fixer} fix --diff --using-cache=no \
    --rules=@PSR12,no_unused_imports,ordered_imports {scope}
```

When a project `.php-cs-fixer.dist.php` exists, omit `--rules` (use project config).
Always pass `--path-mode=intersection` when combined with explicit file lists.

### rector — Safe-Sets Fix

```bash
{ctx.runner} {ctx.tools.rector} process --set=dead-code --set=code-quality \
    --output-format=json {scope}
```

Only apply rector sets classified **SAFE** in `autofix-safety.md`. Never apply REVIEW sets
here. See the safety reference for the exact `--set` flags to include/exclude.

## Probing Availability

`magento2-context` resolves each tool into `{ctx.tools.<name>}`. A `null` value means the
tool was not found; skip gracefully and record in `skipped[]`.

```json
{
  "phpcs":        "vendor/bin/phpcs",
  "phpcbf":       "vendor/bin/phpcbf",
  "phpstan":      "vendor/bin/phpstan",
  "phpmd":        "vendor/bin/phpmd",
  "rector":       "vendor/bin/rector",
  "php_cs_fixer": "vendor/bin/php-cs-fixer"
}
```

Tools absent from `{ctx.tools}` are recorded in the output's `skipped[]` array. A partial
toolchain still produces useful findings — the skill never aborts because one tool is missing.
