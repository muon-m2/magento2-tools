# Tool Probe

Algorithm for resolving the `tools.*` map.

## Probe Recipe (per tool)

For each tool below, probe with the listed command. If exit 0 → record the resolved
command. If exit non-zero or command not found → record `null`.

| Tool key | Probe | Resolved value example |
|----------|-------|------------------------|
| `phpcs` | `[ -x vendor/bin/phpcs ] && vendor/bin/phpcs --version` | `"vendor/bin/phpcs"` |
| `phpstan` | `[ -x vendor/bin/phpstan ] && vendor/bin/phpstan --version` | `"vendor/bin/phpstan"` |
| `phpunit` | `[ -x vendor/bin/phpunit ] && vendor/bin/phpunit --version` | `"vendor/bin/phpunit"` |
| `phpmd` | `[ -x vendor/bin/phpmd ] && vendor/bin/phpmd --version` | `"vendor/bin/phpmd"` |
| `rector` | `[ -x vendor/bin/rector ] && vendor/bin/rector --version` | `"vendor/bin/rector"` |
| `psalm` | `[ -x vendor/bin/psalm ] && vendor/bin/psalm --version` | `"vendor/bin/psalm"` |
| `php-cs-fixer` | `[ -x vendor/bin/php-cs-fixer ] && vendor/bin/php-cs-fixer --version` | `"vendor/bin/php-cs-fixer"` |
| `xmllint` | `command -v xmllint && xmllint --version` (stderr) | `"xmllint"` |
| `composer` | `command -v composer && composer --version` | `"composer"` |
| `semgrep` | `command -v semgrep && semgrep --version` | `"semgrep"` |
| `gitleaks` | `command -v gitleaks && gitleaks version` | `"gitleaks"` |
| `trufflehog` | `command -v trufflehog && trufflehog --version` | `"trufflehog"` |
| `node` | `command -v node && node --version` | `"node"` |
| `pa11y` | `command -v pa11y && pa11y --version` | `"pa11y"` |
| `gh` | `command -v gh && gh --version` | `"gh"` |

## Runner Awareness

Project-local `vendor/bin/*` tools are **layout- and runner-aware**. The bare host probe
(`[ -x vendor/bin/phpcs ]`) only works for a repo-root install run from the workspace root;
it misses a `src/` layout (where the tool is at `src/vendor/bin/phpcs`) and a Docker runner
(where the tool is at `vendor/bin/phpcs` relative to the container working dir, which is the
Magento root). Resolve in this order:

1. **Host path at the Magento root** — `[ -x {magento_root}/vendor/bin/phpcs ]`. Covers both
   `.` and `src/` layouts without spawning a container.
2. **Runner-relative probe** (only if step 1 misses and the runner is Docker, i.e. the tool
   lives inside the image, not on the host mount) — `{runner} test -x vendor/bin/phpcs`.

**Resolved value is always the bare relative `vendor/bin/<tool>`** (relative to the runner's
working dir = the Magento root) for runner-backed modes, or the host path
`{magento_root}/vendor/bin/<tool>` for bare mode. Do **not** store a runner-prefixed string —
consumers prefix `{runner}` themselves (e.g. deploy runs `{runner} vendor/bin/phpcs`), so a
prefixed value would double the runner.

## Why Probe at All

Downstream skills are tool-opportunistic: missing tools are reported as skipped checks,
never as defects. Probing once at the start avoids each skill independently asking
"is phpstan installed?".

## Caching Note

Tool probes are part of the resolved context and live in the same cache file. The cache
is invalidated when `composer.lock` changes (which is when `vendor/bin/*` paths typically
appear or disappear).
