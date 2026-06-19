# Design: skill/command routing disambiguation

**Status:** Approved design (2026-06-17) — pending spec review, then implementation plan.
**Scope:** the `magento2-tools` plugin. Tightens `description` frontmatter on ~7 skills + 2 commands, adds a pinning contract test + a contributor doc. No skill *behaviour*/template/schema changes.
**Author:** drafted via Claude Code for the magento2-tools plugin (audit by a routing-audit subagent).

---

## 1. Why

With 18 skills + 9 commands, Claude routes a natural-language request to a skill **using the skill's `description` frontmatter**. A routing audit found three systemic overlaps that cause mis-fires:

1. **`magento2-feature-implement` is a routing black hole** — "Use when the user asks to add, change, build, or implement **any** Magento 2 functionality" subsumes every creation skill (`module-create`, `adminhtml-form`, `graphql-create`, `eav-attribute`). No negative guard.
2. **Audit/review synonym collisions** — `module-review`'s description literally lists "security review" (= `security-audit`'s trigger); `debug` says "slow queries" (= `performance-audit`). The discriminators exist in skill *bodies* but **not** in the `description`, which is the routing signal.
3. **Vocabulary collisions** — `eav-attribute` and `data-migration` both say "data patch / idempotent"; `module-create` claims "admin form / graphql / attribute" surfaces that the dedicated skills own.

The fix must live **in the descriptions** (and lightly in command descriptions) — a separate routing doc does not influence selection.

## 2. Decisions (locked)

- **Fix routing via `description` edits**, not a routing doc and not command frontmatter changes (`disable-model-invocation` stays as-is on all commands — user's choice).
- **Light command-description tightening** for `/context` and `/snapshot` only (explicit-intent wording); `/review`/`/security`/`/perf` inherit the clarified skill routing and are left as-is.
- **No skill-version-registry bumps** — description-tightening is routing metadata, not a behaviour/JSON/schema/template change (consistent with how prior reference-only changes were not bumped). Note in CHANGELOG `[Unreleased]`.
- **Pin the discriminators with a contract test** so a future reword can't silently drop a guard.
- **Add a contributor-facing "when to use which" table** to `docs/skills-reference.md`.

## 3. Component 1 — skill `description` discriminators

Each edit ADDS a short discriminator clause to the existing `description` (keeps the existing trigger language; only `module-review` also removes the colliding "security review" phrase). Exact verbatim old/new strings are produced in the plan after reading each current `description`.

| Skill | Discriminator to add (intent) |
|---|---|
| `magento2-feature-implement` | "Prefer a narrower dedicated skill when the whole request fits one: a single admin form → `magento2-adminhtml-form`; a GraphQL surface → `magento2-graphql-create`; a single EAV attribute → `magento2-eav-attribute`; a bare module scaffold → `magento2-module-create`. Use this orchestrator for multi-step / multi-surface work or when scope is unclear." |
| `magento2-module-create` | "For a standalone admin form use `magento2-adminhtml-form`, a GraphQL surface `magento2-graphql-create`, or a single EAV attribute `magento2-eav-attribute` — this skill is for a new module/extension scaffold." |
| `magento2-module-review` | Replace the colliding "security review" wording; add: "Per-module architecture/quality review; for security-only depth (CVEs, secrets, EQP) use `magento2-security-audit`, for performance-only depth use `magento2-performance-audit`." |
| `magento2-security-audit` | "Cross-module, dependency-level, and repo-wide depth; for per-module security findings inside a general architecture review use `magento2-module-review`." |
| `magento2-debug` | "Read-only, single-session inspection; for severity-ranked, actionable performance findings use `magento2-performance-audit`." |
| `magento2-performance-audit` | "...as severity-ranked findings (vs the lighter read-only `magento2-debug` slow-query inspection)." |
| `magento2-eav-attribute` | "For non-EAV / bulk data seeding or migration use `magento2-data-migration`." |
| `magento2-data-migration` | "For adding an EAV attribute use `magento2-eav-attribute`." |

Each added clause names at least one **other real skill** — so the pinning test (Component 3) can verify it persists.

## 4. Component 2 — command-description tightening (no frontmatter change)

- `commands/context.md` `description`: add "(use when explicitly asked to resolve/refresh project context)".
- `commands/snapshot.md` `description`: add "(use when explicitly asked for a system health snapshot)".
- No `disable-model-invocation` changes anywhere. No other command files touched.

## 5. Component 3 — pinning contract test (`tests/test-routing-discriminators.sh`)

Asserts the discriminators stay present in the relevant `description` frontmatter:

- `magento2-feature-implement` description references `magento2-adminhtml-form`, `magento2-graphql-create`, and `magento2-eav-attribute`.
- `magento2-module-review` description references both `magento2-security-audit` and `magento2-performance-audit`, and does **not** contain the bare phrase "security review".
- `magento2-security-audit` description references `magento2-module-review`.
- `magento2-debug` description references `magento2-performance-audit`.
- `magento2-eav-attribute` description references `magento2-data-migration` and vice-versa.

Mechanics: for each skill, extract only the `description` block (between `description:` and the closing `---`) and grep within it (so a mention elsewhere in the file doesn't false-pass). Pure bash + awk/grep; runs in `tests/run-all.sh`; shellcheck-clean. The existing `test-skill-frontmatter.sh` continues to validate that descriptions are present/well-formed.

## 6. Component 4 — contributor doc

A short "Choosing between adjacent skills" table in `docs/skills-reference.md` capturing the discriminators (feature-implement vs sub-skills; review vs security vs performance; debug vs performance-audit; eav vs data-migration). Human-facing only; documents intent so future skill edits preserve the boundaries.

## 7. Error handling / non-goals

- **Non-goal:** changing any skill's behaviour, phases, templates, output, or flags — descriptions/routing only.
- **Non-goal:** changing command `disable-model-invocation` or adding/removing commands.
- **Non-goal:** a machine-read routing doc (descriptions are the only routing signal; the doc is for humans).
- The pinning test guards regression but cannot prove semantic disjointness; it checks the specific discriminator references exist.

## 8. Implementation-time verification

- Read each current `description` verbatim before editing (block-scalar YAML; preserve indentation so `test-skill-frontmatter.sh` still parses). Confirm `module-review` currently contains the "security review" phrasing the edit removes.
- After edits: `test-skill-frontmatter.sh`, `test-reference-integrity.sh` (descriptions now name other skills — confirm that's accepted, not flagged), and the new `test-routing-discriminators.sh` all pass; full suite `FAIL: 0`.

## 9. Versioning & docs

- No `skill-versioning.md` changes (routing metadata only).
- CHANGELOG `[Unreleased]` entry. The contributor table lands in `docs/skills-reference.md`.
