# Runner Detection

Algorithm for resolving `{runner}`, `{runner_kind}`, `{magento_cli}`, and `{composer}`.

## Output model

The resolver emits two related fields:

- `runner` — the command-prefix that puts subsequent argv inside a PHP-capable environment.
  - For docker modes it is a non-empty wrapper like `docker compose exec -T -u magento php`.
  - For **bare host PHP** it is the **empty string** (`""`). Downstream callers that do
    `${RUNNER} php -r '...'` therefore produce ` php -r '...'`, which works correctly.
  - When no PHP environment can be detected, the resolver emits `runner: ""` together
    with `runner_kind: "null"`.
- `runner_kind` — one of `null`, `bare`, `docker-compose`, `docker-exec`, `custom`.
  Use this when you need to branch on the mode. Treat `null` as "no PHP available".

Empty `runner` is **only** valid when `runner_kind` is `bare` (or `null`). Consumers that
test `[ -n "$RUNNER" ]` to decide whether PHP is available will incorrectly skip bare
mode — read `runner_kind` instead.

## Priority Order

1. **`CLAUDE.md` hint.** If `CLAUDE.md` contains `Docker prefix:` or `Runner:` (e.g.
   `Docker prefix: docker exec -it battlefield-php`), use the value verbatim.
   `runner_kind = "custom"`. `resolution_source.runner = "CLAUDE.md hint"`.

2. **Docker Compose running container.**
   - Probe: `docker compose ps --services --filter status=running` and check membership of `php`.
   - If matched → `runner = "docker compose exec -T -u {magento_user} php"`,
     `runner_kind = "docker-compose"`.
   - `{magento_user}` resolves from `CLAUDE.md` `Docker user:` or defaults to `magento`.

3. **Bare `docker exec` with a known container.**
   - If `docker ps` shows a container matching `battlefield-php`, `magento.*php`, or
     `m2.*php`, use `docker exec -i {container}`.
   - `runner_kind = "docker-exec"`.

4. **Bare PHP.**
   - Probe: `command -v php && php --version` — both must succeed.
   - `runner = ""` (empty) and `runner_kind = "bare"`.
   - `resolution_source.runner = "bare php on PATH"`.

5. **No runner.** `runner = ""`, `runner_kind = "null"`. Consumers that require PHP must
   report "no PHP runner available" and refuse to proceed.

## Magento CLI Resolution

Once `runner` is resolved:
- If `bin/magento` exists at `src/bin/magento` or `bin/magento`:
  - Docker modes: `magento_cli = "{runner} bin/magento"`.
  - Bare mode: `magento_cli = "bin/magento"`.
- Else: `magento_cli = null`.

The path is relative to the working directory of the runner. For Docker containers
with `WORKDIR /var/www/html`, the command resolves inside the container's workdir.

## Composer Resolution

- Docker modes: `composer = "{runner} composer"`.
- Bare mode (or no runner): if host `composer` is on PATH → `composer = "composer"`,
  else `composer = null`.

## Why Docker Beats Bare PHP

Magento installs that have a `docker-compose.yml` define the correct PHP version,
extensions, and Magento root layout. Host PHP may differ. Use Docker when both are
available; override via `CLAUDE.md` (`Runner: php`) to force bare PHP — that path also
sets `runner_kind = "custom"`.

## Why `-T` and `-u magento`

- `-T` disables TTY — captured output stays clean.
- `-u magento` runs as the Magento non-root user, so file ownership in `var/`, `pub/`,
  `generated/` matches Magento's expectations.

## Edge Cases

| Case | Behaviour |
|------|-----------|
| `docker-compose.yml` exists but no container is running | Fall through to bare PHP (step 4). |
| Two compose services match `php` | Use the first; warn the user. |
| `CLAUDE.md` hint runner fails to exec | Report the error; do NOT silently fall through. The user explicitly asked for this runner. |
| Multiple Magento roots | Resolver fails; ask user which root. |
| No PHP at all | `runner = ""`, `runner_kind = "null"`; consumers degrade. |

## Consumer Pattern

```bash
# Read structured kind, not the legacy runner string.
RUNNER_KIND=$(jq -r .runner_kind .claude/.cache/magento2-context.json)
RUNNER=$(jq -r .runner       .claude/.cache/magento2-context.json)

case "$RUNNER_KIND" in
    bare|docker-compose|docker-exec|custom)
        # PHP is available; ${RUNNER} php -r '...' works in all four modes.
        ;;
    null)
        echo "no PHP runner available" >&2
        exit 1
        ;;
esac
```
