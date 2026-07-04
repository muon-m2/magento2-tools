# Artifact Layout

Single source of truth for **where** every `magento2-*` skill writes its result
artifacts and **what** it names them. Consumed by every artifact-producing skill.

## Output root

All artifacts are written under an **output root**, resolved once per run:

- **Default:** `{ctx.docs_root}` — i.e. `.docs`, anchored at the project root.
- **Override:** the `--docs-root=<path>` argument. When a caller (e.g.
  `magento2-feature-implement`) passes it, the skill writes under `<path>` instead
  of `.docs`. Scripts read it from the `DOCS_ROOT` env var.

Every artifact goes to **`{output_root}/{category}/{basename}`**. The output root is
the ROOT only — the skill always appends its own `{category}` subdirectory.

### Recipe — scripts (bash)

    DOCS_ROOT="${DOCS_ROOT:-.docs}"
    OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/<category>}"

### Recipe — skills (SKILL.md)

> This skill accepts `--docs-root=<path>` (see
> `magento2-context/references/artifact-layout.md`). When set, write artifacts under
> `<path>/<category>/` (scripts: pass `DOCS_ROOT=<path>`); otherwise default to
> `{ctx.docs_root}/<category>/`.

Because env vars do NOT persist across Skill-tool Bash calls, `--docs-root` is always
passed explicitly per invocation — never assumed from a prior `export`.

## Filename scheme

- **Module scope:** `{TARGET_MODULE}-{kind}-{YYYY-MM-DD}` — underscore module name,
  e.g. `Acme_OrderExport-security-2026-07-03`.
- **Site / vendor scope:** `{kind}-{scope}-{YYYY-MM-DD}`, e.g. `security-site-2026-07-03`.

Markdown, JSON, and SARIF of one run share the basename apart from the extension.

## Category registry

| Skill | Category dir | Kind token | Emitter |
|-------|-------------|-----------|---------|
| magento2-module-review | `reviews` | `review` | script (emit-json) |
| magento2-security-audit | `audits` | `security` | script (build-findings) |
| magento2-performance-audit | `audits` | `perf` | script (build-findings) |
| magento2-static-analysis | `quality` | `quality` | script (build-findings) |
| magento2-marketplace-prep | `marketplace` | `readiness` | script (build-findings) |
| magento2-accessibility-audit | `accessibility` | `a11y` | script (build-findings) |
| magento2-breeze-compat-audit | `breeze-compat` | `breeze-compat` | script (build-findings) |
| magento2-module-upgrade | `upgrades` | `upgrade` | inline (MD + JSON) |
| magento2-test-generate | `tests` | `coverage` | LLM report |
| magento2-docs-generate | `docs-generated` | (run report) | LLM report |
| magento2-deploy | `deployments` | (timestamped) | script (deploy) |
| magento2-release | `releases` | (per version) | LLM report |
| magento2-i18n | `i18n` | (run report) | LLM report |
| magento2-debug | `debug` | (opt-in --save) | LLM report |
| magento2-bug-fix | `bug-fixes/{slug}` | (dossier) | LLM report |
| magento2-adminhtml-form | `adminhtml-forms` | (run report) | LLM report |
| magento2-adminhtml-listing | `adminhtml-listings` | (run report) | LLM report |
| magento2-cli-command | `cli-commands` | (run report) | LLM report |
| magento2-eav-attribute | `eav-attributes` | (run report) | LLM report |
| magento2-extension-point | `extension-points` | (run report) | LLM report |
| magento2-indexer | `indexers` | (run report) | LLM report |
| magento2-message-queue | `message-queues` | (run report) | LLM report |
| magento2-system-config | `system-config` | (run report) | LLM report |
| magento2-data-migration | `migrations` | (run report) | LLM report |

## Orchestrated runs

`magento2-feature-implement` sets `--docs-root=.docs/{FeatureName}` on every sub-skill
invocation, so the whole run's artifacts nest under one feature folder — the feature-owned
files (`blueprint.md`, `plan.md`, `report.md`, `spec.md`, `guides/`, `user-docs/`, `smoke/`)
at its root, and each sub-skill's output under its category subdir
(`.docs/{FeatureName}/reviews/`, `/tests/`, `/deployments/`, …).
