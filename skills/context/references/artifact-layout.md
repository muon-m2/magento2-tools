# Artifact Layout

Single source of truth for **where** every skill in this pack writes its result
artifacts and **what** it names them. Consumed by every artifact-producing skill.

## Output root

All artifacts are written under an **output root**, resolved once per run:

- **Default:** `{ctx.docs_root}` — i.e. `.docs`, anchored at the project root.
- **Override:** the `--docs-root={path}` argument. When a caller (e.g.
  `feature`) passes it, the skill writes under `{path}` instead
  of `.docs`. Scripts read it from the `DOCS_ROOT` env var.

Every artifact goes to **`{output_root}/{category}/{basename}`**. The output root is
the ROOT only — the skill always appends its own `{category}` subdirectory.

### Recipe — scripts (bash)

    DOCS_ROOT="${DOCS_ROOT:-.docs}"
    OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/{category}}"

### Recipe — skills (SKILL.md)

> This skill accepts `--docs-root={path}` (see
> `context/references/artifact-layout.md`). When set, write artifacts under
> `{path}/{category}/` (scripts: pass `DOCS_ROOT={path}`); otherwise default to
> `{ctx.docs_root}/{category}/`.

Because env vars do NOT persist across Skill-tool Bash calls, `--docs-root` is always
passed explicitly per invocation — never assumed from a prior `export`.

## Filename scheme

- **Module scope:** `{Vendor}_{Module}-{kind}-{YYYY-MM-DD}` (the underscore-joined module
  name that scripts read as the `TARGET_MODULE` env var) — e.g.
  `Acme_OrderExport-security-2026-07-03`.
- **Site / vendor scope:** `{kind}-{scope}-{YYYY-MM-DD}`, e.g. `security-site-2026-07-03`.

Markdown, JSON, and SARIF of one run share the basename apart from the extension.

## Category registry

| Skill | Category dir | Kind token | Emitter |
|-------|-------------|-----------|---------|
| review | `reviews` | `review` | script (emit-json) |
| security | `audits` | `security` | script (build-findings) |
| perf-audit | `audits` | `perf` | script (build-findings) |
| lint | `quality` | `quality` | script (build-findings) |
| marketplace | `marketplace` | `readiness` | script (build-findings) |
| a11y-audit | `accessibility` | `a11y` | script (build-findings) |
| breeze-compat | `breeze-compat` | `breeze-compat` | script (build-findings) |
| audit | `audits` | `audit` | script (consolidate → emit-json) |
| audit (`--compare`) | `audits` | `closure` | script (compare-findings → emit-json) |
| triage | `remediation` | `plan` | script (emit-json) |
| remediate | `remediation` | `report` | LLM report |
| upgrade | `upgrades` | `upgrade` | inline (MD + JSON) |
| test-generate | `tests` | `coverage` | LLM report |
| docs | `docs-generated` | (run report) | LLM report |
| deploy | `deployments` | (timestamped) | script (deploy) |
| release | `releases` | (per version) | LLM report |
| i18n | `i18n` | (run report) | LLM report |
| debug | `debug` | (opt-in --save) | LLM report |
| fix | `bug-fixes/{slug}` | (dossier) | LLM report |
| admin-form | `adminhtml-forms` | (run report) | LLM report |
| admin-listing | `adminhtml-listings` | (run report) | LLM report |
| cli-command | `cli-commands` | (run report) | LLM report |
| eav-attribute | `eav-attributes` | (run report) | LLM report |
| extension-point | `extension-points` | (run report) | LLM report |
| indexer | `indexers` | (run report) | LLM report |
| widget | `widgets` | (run report) | LLM report |
| message-queue | `message-queues` | (run report) | LLM report |
| system-config | `system-config` | (run report) | LLM report |
| data-migration | `migrations` | (run report) | LLM report |

Two categories are deliberately shared, and the reason is the same in both cases — one cycle,
one folder:

- **`remediation/`** holds `triage`'s plan *and* `remediate`'s run report. They are the two
  halves of one remediation run, and the precedent already exists (`security` and `perf-audit`
  both write into `audits/`).
- **`audits/`** holds `audit`'s consolidated document *and* its `--compare` closure. The
  closure document is **`audit`'s** artifact, not `remediate`'s: exactly one skill owns
  verdicts and scores, so the skill that executes the remediation never grades its own work.
  `remediate`'s report links to it.

## Input paths under the output root

One path under the output root is an **input**, not an artifact:

| Path | Owner | Purpose |
|------|-------|---------|
| `{output_root}/findings/waivers.yml` | `triage` | Per-fingerprint suppression decisions (false-positive / accepted-risk / wont-fix, with an optional `expires`). Read by `context/scripts/waivers-lib.sh`. |

It is hand-maintained and belongs in version control. When the output root is gitignored the
suppressions are local only and reset on the next clone — `triage` warns and suggests
relocating it with `--waivers=<path>`.

## Orchestrated runs

`feature` sets `--docs-root=.docs/{FeatureName}` on every sub-skill
invocation, so the whole run's artifacts nest under one feature folder — the feature-owned
files (`blueprint.md`, `plan.md`, `report.md`, `spec.md`, `guides/`, `user-docs/`, `smoke/`)
at its root, and each sub-skill's output under its category subdir
(`.docs/{FeatureName}/reviews/`, `/tests/`, `/deployments/`, …).
