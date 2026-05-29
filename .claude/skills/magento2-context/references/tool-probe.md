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

For project-local `vendor/bin/*` tools, also check the **runner-relative** path. If the
`runner` is Docker, `vendor/bin/phpcs` lives inside the container — probe with
`{runner} test -x vendor/bin/phpcs`.

If a tool is reachable only via the runner, record the full runner-prefixed path:
`"docker compose exec -T -u magento php vendor/bin/phpcs"`.

## Why Probe at All

Downstream skills are tool-opportunistic: missing tools are reported as skipped checks,
never as defects. Probing once at the start avoids each skill independently asking
"is phpstan installed?".

## Caching Note

Tool probes are part of the resolved context and live in the same cache file. The cache
is invalidated when `composer.lock` changes (which is when `vendor/bin/*` paths typically
appear or disappear).
