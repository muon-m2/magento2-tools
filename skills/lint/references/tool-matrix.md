# Static Analysis Tool Matrix

Which tool detects vs fixes what, and how to invoke each via `{ctx.runner}` and `{ctx.tools}`.

All commands below assume the tool path was resolved by `context` into `{ctx.tools}`.
Prefix with `{ctx.runner}` when running inside a Docker container (e.g.
`docker compose exec -T php vendor/bin/phpcs ...`).

## Tool Roles

| Tool | Role | Fixes code? | Config required? |
|------|------|-------------|-----------------|
| `phpcs` (Magento2 standard) | Detect coding-standard violations | No — use `phpcbf` | `--standard=Magento2` |
| `phpcbf` (Magento2 standard) | Auto-fix coding-standard violations | **Yes** (auto-applied) | `--standard=Magento2` |
| `php-cs-fixer` | Auto-fix formatting (PER-CS baseline) | **Yes** (auto-applied) | `.php-cs-fixer.dist.php` or built-in rules |
| `rector` `--dry-run` | Detect refactoring opportunities (proposal only) | No — never auto-applied; manual post-review step | `rector.php` |
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

**Strip any non-JSON preamble before parsing.** PHP_CodeSniffer 3.13.x writes deprecation notices
to **stdout, ahead of** the `--report=json` payload — the Magento2 standard's GraphQL
custom-tokenizer sniffs trigger it:

```
DEPRECATED: Support for custom tokenizers will be removed in PHP_CodeSniffer 4.0.
The Magento2.GraphQL.ValidFieldName sniff is listening for GRAPHQL.
{"totals":{...},"files":{...}}
```

That makes the payload invalid JSON. A parser that falls back to `[]` on a decode error drops
every violation and reports the module clean. Drop everything before the first line beginning with
`{`, and report the decode failure to `scanner_errors` if the payload is still unparseable.

**Check that phpcs scanned something.** The JSON report lists *every* file phpcs scanned, clean
ones included, so an empty `files` object means it looked at nothing. Unless the target genuinely
has no `.php`/`.phtml` files, record that in `scanner_errors` and mark phpcs `degraded` in `tools` —
never report it as a clean pass. The usual cause is an exclude pattern: `--ignore` is an unanchored
regex over each file's realpath, so `*/var/*` matches a container's whole `/var/www/…` install root
and `*/vendor/*` a whole Composer-installed module. Anchor every exclude at the target instead
(`<target>/vendor/*`, …) — `scripts/exclude-lib.sh` does, using the realpath the runner sees.

### phpstan — Detect

```bash
{ctx.runner} {ctx.tools.phpstan} analyse --error-format=json --no-progress \
    --memory-limit=2G {scope} > {TMP}/phpstan.json
```

Level: use `phpstan.neon`'s configured level; fall back to `--level=5` if no config exists.
phpstan is report-only — it produces no auto-fixable output. Findings are emitted at a fixed
`medium` severity; phpstan's analysis JSON does not carry a per-message level value, so
level-based severity mapping is not possible at parse time.

**`--memory-limit` is not optional.** Without it phpstan inherits php.ini's default (commonly
128M) and dies on a Magento codebase with *"PHPStan process crashed because it reached configured
PHP memory limit"*, returning `{"totals":{"errors":1},"files":[]}` — a result that reads as clean.
Override via `PHPSTAN_MEMORY_LIMIT`.

**Do not discard phpstan's stderr** (this command previously showed `2>/dev/null`). A crashed run
is the case that most needs reporting, and its diagnostics are what tell a crash apart from a pass.
Two shapes must be handled at parse time:

- a top-level `errors` list carries run-level failures (crash, config error) — surface each one to
  stderr so it reaches `scanner_errors`;
- `files` is a dict keyed by path on success, but a **list** (usually `[]`) on failure — type-guard
  it before calling `.values()`.

### phpmd — Detect

```bash
# Prefer the module's own ruleset when it ships one; fall back to the built-in sets.
{ctx.runner} {ctx.tools.phpmd} {scope} json {scope}/phpmd.xml > {TMP}/phpmd.json
{ctx.runner} {ctx.tools.phpmd} {scope} json cleancode,codesize,controversial,design,naming,unusedcode \
    > {TMP}/phpmd.json
```

Running the built-in sets against a module that deliberately excluded rules re-reports exactly what
the project chose to suppress — most sharply `_resetState()`, whose name is *mandated* by Magento's
`ResetAfterRequestInterface`, tripping `CamelCaseMethodName`. The module ruleset is also what
`validate-module.sh` and the seeded module CI enforce. When a module ruleset is used, say so in the
report: the findings then reflect the rules that module selected for itself, not the built-in set.

**Strip the non-JSON preamble here too.** PHP 8.5 under its built-in defaults (`display_errors=1`,
`error_reporting=E_ALL` — a php-cli container with no php.ini) prints pdepend's
`Deprecated: Non-canonical cast (integer) …` notices on stdout, ahead of the JSON report. PHPMD's
report lists only files that *have* violations, so there is no phpcs-style zero-file check to fall
back on: the anchored `--exclude` list is the only guard against excluding the target itself.

phpmd is report-only. Map `priority` (1-5) to severity: **1→medium, 2→medium, 3→medium, 4→low,
5→info**.

**The map is capped at medium by design — never map phpmd to critical or high.** PHPMD's priority
ranks how important a *rule* is, not how severe a *defect* is: its `CamelCase*` rules ship at
priority 1, so a 1:1 map graded "method is not named in camelCase" as Critical. `audit`
blocks its verdict on Critical **and** High alike (`consolidate.sh` → `FAIL if blockers`), so any
mapping above medium lets a style nit veto a release. Demoting critical→high does not fix this; the
cap does. A defect phpmd surfaces that genuinely warrants High is one another dimension (security,
architecture) is meant to catch on its own merit.

### rector — Dry Run (detect only)

```bash
{ctx.runner} {ctx.tools.rector} process --dry-run --output-format=json {scope} \
    > {TMP}/rector.json
```

Outputs a list of proposed transforms. `--output-format=json` requires `--dry-run`.
Rector findings are **proposals only** — the developer applies any desired changes
manually after reviewing each proposed transform. Rector is never auto-applied by this
skill. Categorise each proposal by the rector set it belongs to; see `autofix-safety.md`
for guidance on which transforms are lower-risk vs require deeper review.

## Fix Commands (auto-apply, Phase 3)

Only `phpcbf` and `php-cs-fixer` are auto-applied. Rector is detection/proposal only.

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

## Probing Availability

`context` resolves each tool into `{ctx.tools.<name>}`. A `null` value means the
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
