---
name: magento2-context
description:
    Resolve Magento 2 project context — vendor prefix, edition, Magento version, PHP version,
    shell runner (Docker vs bare PHP), Magento CLI, active theme, and available quality tools.
    Use this skill from every other magento2-* skill to capture a single source of truth for
    project context. Emits a JSON document; caches to .claude/.cache/magento2-context.json
    keyed by composer.lock hash. Library skill — consumed by other skills, rarely invoked
    directly by humans.
---

# Magento 2 Context Resolver

Library skill consumed by every `magento2-*` skill. Produces a JSON document describing
the project's Magento 2 context. Always emit the JSON to the conversation; also persist it
to `.claude/.cache/magento2-context.json`.

## Core Rules

- **Resolution priority order**: explicit `CLAUDE.md` hint → file/composer probe → tool probe
  → ask the user. Never guess silently.
- **Honest gaps.** If a tool is missing, the field is `null` — never invent a path.
- **Cache by `composer.lock` mtime+sha256.** If the cache exists and `composer.lock` hasn't
  changed since the cached value (and `<24h` old), return the cache.
- **Document the source.** Every resolved value records *where it came from* in
  `resolution_source` so future skills can dispute a wrong value with evidence.
- **One JSON object out.** Output a single JSON document — no prose around it (other than
  a one-line preamble saying "Context resolved.").
- **Artifact location is the project root.** All `.docs/` artifacts produced by any
  `magento2-*` skill (reviews, audits, blueprints, plans, reports, i18n, deploy logs)
  are written under `{project_root}/.docs/`, where `{project_root}` is the working
  directory the session runs from — the directory that contains `{magento_root}`.
  Never write `.docs/` under `{magento_root}`, `app/code`, or any module directory,
  even if a step changes the shell's cwd. When `magento_root` is `"src"`, `.docs/`
  is a sibling of `src/`, not `src/.docs/`.

## Workflow

1. Check cache (`.claude/.cache/magento2-context.json`).
    - If present, age < 24h, and `composer.lock` sha256 matches: return cached JSON.
    - Else: continue.
2. Resolve each context field per `references/`:
    - `vendor` — see `references/vendor-resolution.md`
    - `runner`, `magento_cli`, `composer` — see `references/runner-detection.md`
    - `edition`, `magento_version`, `php_constraint`, `php_version`,
      `framework_constraint` — see `references/version-resolution.md`
    - `theme.frontend`, `theme.adminhtml` — see `references/theme-detection.md`
    - `tools.*` — see `references/tool-probe.md`
3. Assemble JSON per the schema below.
4. Save to cache.
5. Emit JSON.

## Output JSON Schema

```json
{
  "schemaVersion": "1.0",
  "skill": "magento2-context",
  "skillVersion": "1.7.0",
  "resolvedAt": "2026-05-26T14:30:00Z",
  "cacheKey": "lock:sha256-...;json:sha256-...;claude:sha256-...;m2:sha256-...;env:<M2_MAGENTO_ROOT>|<M2_PHP_CONTAINER>",

  "vendor": "Acme",
  "vendor_lower": "acme",

  "project_root": ".",
  "magento_root": "src",
  "module_dir": "src/app/code",
  "docs_root": ".docs",
  "edition": "open-source",
  "magento_version": "2.4.7-p1",

  "php_version": "8.2.15",
  "php_constraint": "~8.2.0",
  "framework_constraint": "103.0.7-p1",

  "runner": "docker compose exec -T -u magento php",
  "runner_kind": "docker-compose",
  "magento_cli": "docker compose exec -T -u magento php bin/magento",
  "composer": "docker compose exec -T -u magento php composer",

  "theme": {
    "frontend": "hyva",
    "frontend_source": "src/composer.json:hyva-themes/* dependency (installed, active-theme unverified)",
    "adminhtml": "Magento/backend",
    "adminhtml_source": "src/app/etc/config.php:themes[].area=adminhtml",
    "breeze": {
      "installed": false,
      "active": false,
      "parent": null,
      "packages": [],
      "source": null
    }
  },

  "tools": {
    "phpcs": "vendor/bin/phpcs",
    "phpstan": "vendor/bin/phpstan",
    "phpunit": "vendor/bin/phpunit",
    "phpmd": "vendor/bin/phpmd",
    "rector": null,
    "psalm": null,
    "php-cs-fixer": "vendor/bin/php-cs-fixer",
    "xmllint": "xmllint",
    "composer": "composer",
    "semgrep": null,
    "gitleaks": null,
    "trufflehog": null,
    "node": "node",
    "pa11y": null,
    "gh": "gh"
  },

  "resolution_source": {
    "vendor": "CLAUDE.md:Vendor prefix",
    "runner": "docker compose ps probe (php running)",
    "magento_cli": "{runner} + bin/magento exists",
    "composer": "{runner} + composer",
    "edition": "src/composer.json:magento/product-community-edition",
    "magento_version": "src/composer.json:magento/product-community-edition",
    "php_version": "docker-compose:php -r",
    "theme.frontend": "src/composer.json:hyva-themes/* dependency",
    "theme.adminhtml": "src/app/etc/config.php:themes[].area=adminhtml"
  }
}
```

### Field reference

- `project_root` — the working directory the session runs from, expressed relative to
  itself (`.`). All `.docs/` artifacts are anchored here. It is the parent of
  `{magento_root}`; when Magento is installed at the repo root, `project_root` and
  `magento_root` coincide but `.docs/` still sits beside `app/code`, never inside it.
- `magento_root` — directory holding the Magento installation relative to
  `{project_root}` (e.g. `"src"` or `"."`). Used to locate `app/code`, `app/etc`, etc.
  Never use it to anchor `.docs/`.
- `docs_root` — resolved path to the artifact directory, `{project_root}/.docs`. Skills
  and scripts write under this path; they must not join it with `{magento_root}`.
- `runner` — command prefix that places subsequent argv inside a PHP-capable
  environment. Empty string for bare host PHP; non-empty (e.g. `docker compose exec ...`)
  for containerized projects. Downstream `${RUNNER} php -r '...'` works in both cases.
- `runner_kind` — one of `null`, `bare`, `docker-compose`, `docker-exec`, `custom`.
  Use this when you need to branch on the runner *mode* rather than its string form.
  Treat `null` as "no PHP environment detected"; `bare` is valid even though `runner`
  is empty.
- `theme.frontend` / `theme.adminhtml` — active theme as resolved from
  `app/etc/config.php`. `null` when no active theme can be confirmed; never silently
  defaulted to `custom`. Always read alongside `theme.frontend_source` /
  `theme.adminhtml_source` to know how the value was derived.
- `theme.breeze` — Swissup Breezefront detection. `installed` is `true` when any
  `swissup/breeze-*` (or `swissup/module-breeze`) package is required in composer.
  `active` is `true` only when `theme.frontend` (or a `<parent>` in its app/design chain)
  resolves to a Breeze theme; `parent` is that Breeze theme code (e.g.
  `Swissup/breeze-evolution`), else `null`. `packages` lists the matched composer
  packages; `source` records how the verdict was reached. The `magento2-breeze-*` skills
  refuse to run when `installed` is `false` and print the install command instead. See
  `references/theme-detection.md`.

## Consumption Pattern (for caller skills)

```
1. Invoke this skill (or read the cache file directly if you're an inline script).
2. Capture the JSON as `{ctx}`.
3. Use `{ctx.vendor}`, `{ctx.runner}`, `{ctx.magento_cli}`, `{ctx.tools.phpcs}` etc.
4. Do not re-resolve any of these values independently.
5. If a required value is null (e.g. magento_cli for a deploy skill), abort with a
   clear error explaining what's missing.
```

## Cache Invalidation

The cache becomes stale when any of:

- `composer.lock` sha256 changes
- `composer.json` sha256 changes
- `CLAUDE.md` sha256 changes
- `.claude/m2.json` sha256 changes (the optional layout/container override file)
- the `M2_MAGENTO_ROOT` or `M2_PHP_CONTAINER` env override changes
- `--no-cache` argument supplied

The cache key is composed as
`lock:<sha>;json:<sha>;claude:<sha>;m2:<sha>;env:<M2_MAGENTO_ROOT>|<M2_PHP_CONTAINER>` and
stored on the cached JSON; the resolver short-circuits only when the recomputed key is
byte-identical. Separately, a TTL (default 24h; `M2_CACHE_TTL` seconds, `0` disables) bounds
how long a key-match can serve a possibly-stale *runner* state, since runner availability is
not part of the key.

Force a refresh by deleting `.claude/.cache/magento2-context.json` or passing `--no-cache`.

## Reference Files

- `references/vendor-resolution.md` — algorithm + edge cases for `{vendor}`.
- `references/runner-detection.md` — Docker vs bare PHP resolution.
- `references/version-resolution.md` — Magento + PHP + framework constraint resolution.
- `references/theme-detection.md` — Luma / Hyva / custom theme detection.
- `references/tool-probe.md` — opt-in tool detection rules.
- `references/naming.md` — authoritative naming conventions (consumed by all builder skills).
- `references/php-coding-style.md` — PER-CS 3.0 baseline + Magento-2-precedence rule for all
  generated/modified PHP (consumed by every builder skill and by `magento2-module-review`).
- `references/tdd-discipline.md` — shared test-first (red → green → refactor) discipline + the
  behaviour/boilerplate line (consumed by `magento2-bug-fix`, `magento2-feature-implement`,
  `magento2-data-migration`, `magento2-eav-attribute`).
- `references/severity.md` — shared severity scale (consumed by all findings-producing skills).
- `references/skill-versioning.md` — current skill versions + bump rules; consumed by every artefact-producing skill.
- `references/findings-schema.md` — shared JSON + SARIF schema for finding-producing skills (review, security-audit,
  performance-audit, module-upgrade).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/resolve-context.sh` — emits the JSON to stdout. Use when an automated path
  needs the JSON without spawning an LLM-driven resolver pass.
- `${CLAUDE_SKILL_DIR}/scripts/probe-tools.sh` — reusable tool-probe helper.
