# Skill Routing Disambiguation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten `description` frontmatter on 8 skills + 2 commands so natural-language requests route to the right skill, and pin the discriminators with a contract test — fixing the routing overlaps the audit found.

**Architecture:** Append a one-line discriminator clause to each flagged skill's `description` block (the routing signal), naming the sibling skill(s) it defers to. Light explicit-intent wording on `/context` + `/snapshot` descriptions (no `disable-model-invocation` change). A new `tests/test-routing-discriminators.sh` extracts each `description` block and asserts the cross-references persist. No skill behaviour/template/schema changes; no skill-version bumps.

**Tech Stack:** YAML frontmatter edits, bash + awk/grep contract test, the repo's `tests/run-all.sh` harness.

**Reference:** design spec `.docs/skill-routing-disambiguation-design.md`. NOTE: `magento2-feature-implement`'s description uses **2-space** indentation; the other 7 skills use **4-space** — preserve each file's existing indent in edits.

---

### Task 1: Pinning test + description edits (TDD)

**Files:** Create `tests/test-routing-discriminators.sh`; modify 8 `skills/*/SKILL.md` + `commands/context.md` + `commands/snapshot.md`.

- [ ] **Step 1: Write the pinning test.** Create `tests/test-routing-discriminators.sh`:

```bash
#!/usr/bin/env bash
# test-routing-discriminators.sh — pin the routing disambiguation. Each disambiguated skill's
# `description` frontmatter must reference the sibling skill(s) it defers to, so a future reword
# can't silently drop a routing guard. Scoped to the description block (not the whole file).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0

# Print only the YAML `description:` block of a SKILL.md (the 'description:' line plus its
# indented continuation lines, up to the next top-level key or the closing '---').
desc() { # skill-name
    awk '
        NR==1 && $0=="---" { infm=1; next }
        infm && $0=="---" { exit }
        infm && /^description:/ { indesc=1; print; next }
        infm && indesc && /^[A-Za-z_-]+:/ { indesc=0 }
        infm && indesc { print }
    ' "skills/magento2-$1/SKILL.md"
}

check() { # skill ref...
    local skill="$1"; shift
    local d ref
    d="$(desc "$skill")"
    for ref in "$@"; do
        printf '%s' "$d" | grep -q "$ref" \
            || { echo "FAIL: magento2-$skill description must reference '$ref'"; FAIL=1; }
    done
}

check feature-implement   magento2-adminhtml-form magento2-graphql-create magento2-eav-attribute
check module-create       magento2-adminhtml-form magento2-graphql-create magento2-eav-attribute
check module-review       magento2-security-audit magento2-performance-audit
check security-audit      magento2-module-review
check debug               magento2-performance-audit
check performance-audit   magento2-debug
check eav-attribute       magento2-data-migration
check data-migration      magento2-eav-attribute

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "routing discriminators: all cross-references present"
exit 0
```

- [ ] **Step 2: Run the test — RED.**

Run: `bash tests/test-routing-discriminators.sh`
Expected: multiple `FAIL: … must reference …` lines, exit 1 (the sibling references don't exist in the descriptions yet — e.g. feature-implement names `module-create`/`module-review` today but not `adminhtml-form`/`graphql-create`/`eav-attribute`).

- [ ] **Step 3: Edit `skills/magento2-feature-implement/SKILL.md`** (2-space indent). Edit:

OLD:
```
  folder's plan.md and resumes from the first unchecked task. Without an explicit
  `.docs/{FeatureName}` path, treat the request as a new feature and start from Phase 1.
```
NEW:
```
  folder's plan.md and resumes from the first unchecked task. Without an explicit
  `.docs/{FeatureName}` path, treat the request as a new feature and start from Phase 1.
  Prefer a narrower dedicated skill when the whole request fits one: a single admin form goes to
  magento2-adminhtml-form; a GraphQL surface to magento2-graphql-create; a single EAV attribute to
  magento2-eav-attribute; a bare module scaffold to magento2-module-create. Use this orchestrator
  for multi-step or multi-surface work, or when scope is unclear.
```

- [ ] **Step 4: Edit `skills/magento2-module-create/SKILL.md`** (4-space indent). Edit:

OLD:
```
    leaves empty placeholder files. Works without a running Magento instance, Docker, or installed
    Composer dependencies.
```
NEW:
```
    leaves empty placeholder files. Works without a running Magento instance, Docker, or installed
    Composer dependencies. For a standalone admin form use magento2-adminhtml-form, a GraphQL
    surface use magento2-graphql-create, or a single EAV attribute use magento2-eav-attribute —
    this skill scaffolds a new module/extension, not a single sub-surface.
```

- [ ] **Step 5: Edit `skills/magento2-module-review/SKILL.md`** (single-line description). Edit:

OLD:
```
should use available static-analysis tools opportunistically.
```
NEW:
```
should use available static-analysis tools opportunistically. For security-only depth (CVEs, secrets, Marketplace EQP) use magento2-security-audit; for performance-only depth use magento2-performance-audit.
```

- [ ] **Step 6: Edit `skills/magento2-security-audit/SKILL.md`** (4-space indent). Edit:

OLD:
```
    Marketplace EQP static rules, and cross-module pattern
    detection.
```
NEW:
```
    Marketplace EQP static rules, and cross-module pattern
    detection. This is cross-module, dependency-level, and repo-wide depth; for per-module
    security findings within a general architecture/quality review use magento2-module-review.
```

- [ ] **Step 7: Edit `skills/magento2-debug/SKILL.md`** (4-space indent). Edit:

OLD:
```
    slow-queries / snapshot / xdebug.
```
NEW:
```
    slow-queries / snapshot / xdebug. Read-only single-session inspection; for severity-ranked,
    actionable performance findings (N+1, caching) use magento2-performance-audit.
```

- [ ] **Step 8: Edit `skills/magento2-performance-audit/SKILL.md`** (4-space indent). Edit:

OLD:
```
    a running Magento instance.
```
NEW:
```
    a running Magento instance. Produces actionable, severity-ranked findings — vs the lighter
    read-only slow-query inspection in magento2-debug.
```

- [ ] **Step 9: Edit `skills/magento2-eav-attribute/SKILL.md`** (4-space indent). Edit:

OLD:
```
    Produces a Setup/Patch/Data/ class that passes magento2-module-review.
```
NEW:
```
    Produces a Setup/Patch/Data/ class that passes magento2-module-review. For non-EAV or bulk
    data seeding/migration use magento2-data-migration.
```

- [ ] **Step 10: Edit `skills/magento2-data-migration/SKILL.md`** (4-space indent). Edit:

OLD:
```
    existing data idempotently. Produces idempotent patches that pass magento2-module-review.
```
NEW:
```
    existing data idempotently. Produces idempotent patches that pass magento2-module-review. For
    adding an EAV attribute use magento2-eav-attribute.
```

- [ ] **Step 11: Edit `commands/context.md`** description line. Edit:

OLD:
```
description: Resolve the Magento 2 project context — vendor, runner, versions, theme, tools (magento2-context)
```
NEW:
```
description: Resolve the Magento 2 project context — vendor, runner, versions, theme, tools (magento2-context). Use when explicitly asked to resolve or refresh project context.
```

- [ ] **Step 12: Edit `commands/snapshot.md`** description line. Edit:

OLD:
```
description: One-page Magento 2 health snapshot — indexers, caches, queues, cron, versions (magento2-debug)
```
NEW:
```
description: One-page Magento 2 health snapshot — indexers, caches, queues, cron, versions (magento2-debug). Use when explicitly asked for a system health snapshot.
```

- [ ] **Step 13: Run the test — GREEN — and the full suite.**

Run: `bash tests/test-routing-discriminators.sh`
Expected: `routing discriminators: all cross-references present`, exit 0.

Run: `bash tests/run-all.sh`
Expected: `FAIL: 0`. **Critically**, `test-skill-frontmatter.sh` (descriptions still parse as valid frontmatter after the block-scalar edits) and `test-reference-integrity.sh` (descriptions naming sibling skills are accepted — bare skill names already appear in descriptions today, e.g. feature-implement names `magento2-module-create`) must both PASS. If `test-reference-integrity.sh` fails on the new skill-name mentions, STOP and report the exact rule — do not weaken a description.

- [ ] **Step 14: shellcheck the new test if available.**

Run: `command -v shellcheck >/dev/null && shellcheck --severity=error --exclude=SC1091 tests/test-routing-discriminators.sh && echo CLEAN || echo "shellcheck absent — CI runs it"`

- [ ] **Step 15: Commit.**

```bash
chmod +x tests/test-routing-discriminators.sh
git add tests/test-routing-discriminators.sh skills/magento2-feature-implement/SKILL.md \
  skills/magento2-module-create/SKILL.md skills/magento2-module-review/SKILL.md \
  skills/magento2-security-audit/SKILL.md skills/magento2-debug/SKILL.md \
  skills/magento2-performance-audit/SKILL.md skills/magento2-eav-attribute/SKILL.md \
  skills/magento2-data-migration/SKILL.md commands/context.md commands/snapshot.md
git commit -m "feat(routing): disambiguate skill/command descriptions + pinning test"
```

---

### Task 2: Documentation

**Files:** modify `docs/skills-reference.md`, `CHANGELOG.md`.

- [ ] **Step 1: Append a "Choosing between adjacent skills" section to `docs/skills-reference.md`.** Append this at the END of the file:

```markdown

## Choosing between adjacent skills

Several skills have adjacent triggers. The `description` frontmatter encodes these boundaries so
Claude routes correctly; they are summarized here for contributors. When you add or reword a
description, keep its cross-references intact — `tests/test-routing-discriminators.sh` enforces the
key ones.

| If the request is… | Use | Not |
|---|---|---|
| A single admin edit form | `magento2-adminhtml-form` | `magento2-feature-implement` / `magento2-module-create` |
| A GraphQL query/mutation/type | `magento2-graphql-create` | `magento2-feature-implement` / `magento2-module-create` |
| A single product/customer/category attribute | `magento2-eav-attribute` | `magento2-module-create` / `magento2-data-migration` |
| Bulk/reference data seeding, M1 import, transforms | `magento2-data-migration` | `magento2-eav-attribute` |
| A new module/extension scaffold | `magento2-module-create` | `magento2-feature-implement` (unless multi-surface) |
| Multi-step / multi-surface / unclear-scope work | `magento2-feature-implement` | the single sub-skills above |
| Per-module architecture/quality review | `magento2-module-review` | `magento2-security-audit` / `magento2-performance-audit` |
| Security depth (CVEs, secrets, EQP, cross-module/repo) | `magento2-security-audit` | `magento2-module-review` |
| Performance depth (N+1, caching, ranked findings) | `magento2-performance-audit` | `magento2-debug` |
| Read-only log/DI/queue inspection, one session | `magento2-debug` | `magento2-performance-audit` |
```

- [ ] **Step 2: Add a CHANGELOG bullet** under the existing `## [Unreleased]` → `### Added` (a slash-command bullet is already there from the previous release). Edit `CHANGELOG.md`:

OLD:
```
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```
NEW:
```
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.
- **Routing disambiguation** — tightened `description` frontmatter on `magento2-feature-implement`
  (negative guard toward narrower skills), `magento2-module-review` / `magento2-security-audit`
  (scope boundary), `magento2-debug` / `magento2-performance-audit` (read-only inspection vs
  severity-ranked findings), `magento2-module-create`, and `magento2-eav-attribute` ↔
  `magento2-data-migration` (cross-references), so natural-language requests route to the right
  skill. The `/context` and `/snapshot` command descriptions note explicit-intent use. Pinned by
  `tests/test-routing-discriminators.sh`. Routing metadata only — no skill-version or behaviour
  change.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```
(If the OLD block isn't found verbatim, STOP → NEEDS_CONTEXT.)

- [ ] **Step 3: Verify & commit.**

Run: `grep -n 'Choosing between adjacent skills' docs/skills-reference.md && grep -n 'Routing disambiguation' CHANGELOG.md && bash tests/run-all.sh | tail -3`
Expected: both hits; suite `FAIL: 0`.

```bash
git add docs/skills-reference.md CHANGELOG.md
git commit -m "docs(routing): contributor skill-disambiguation table + CHANGELOG"
```

---

### Task 3: Final verification

- [ ] **Step 1: Full suite + clean tree.** Run: `bash tests/run-all.sh | tail -4 && git status --short`. Expect `FAIL: 0` (incl. `test-routing-discriminators.sh`, `test-skill-frontmatter.sh`, `test-reference-integrity.sh` all PASS); working tree shows only pre-existing untracked `.gitignore`/`.claude/`/`.docs/`.

- [ ] **Step 2: Scope check.** Run: `git diff --stat $(git merge-base HEAD main)..HEAD`. Expect only: the 8 SKILL.md, `commands/context.md`, `commands/snapshot.md`, `tests/test-routing-discriminators.sh`, `docs/skills-reference.md`, `CHANGELOG.md`. No template/script/other-skill changes; `skill-versioning.md` NOT changed.

- [ ] **Step 3: Frontmatter parse sanity.** Run a YAML parse of each edited skill's frontmatter to confirm the block scalars are still valid:
```bash
for s in feature-implement module-create module-review security-audit debug performance-audit eav-attribute data-migration; do
  python3 - "skills/magento2-$s/SKILL.md" <<'PY'
import sys
t=open(sys.argv[1]).read().split('---',2)
import re
# crude: ensure there are 2 '---' fences and a description key in the frontmatter
assert t[0]=='' and 'description:' in t[1], sys.argv[1]
print("ok", sys.argv[1])
PY
done
```
Expected: 8 `ok` lines. (If `python3` is absent, skip — `test-skill-frontmatter.sh` already covers parse validity.)

---

## Self-review

**Spec coverage** (`.docs/skill-routing-disambiguation-design.md`):
- §3 discriminators → Task 1 Steps 3–10 (all 8 skills), verbatim with preserved indentation.
- §4 command tightening → Steps 11–12 (no frontmatter/`disable-model-invocation` change).
- §5 pinning test → Step 1 + Step 13 (RED→GREEN); scoped to the description block via the `desc()` awk.
- §6 contributor doc → Task 2 Step 1.
- §9 versioning → no `skill-versioning.md` edit (Task 3 Step 2 asserts it); CHANGELOG → Task 2 Step 2.
- §8 verification → Step 13 (frontmatter + reference-integrity must pass) and Task 3 Step 3.

**Placeholder scan:** every edit gives verbatim OLD/NEW; the test is complete; docs blocks are verbatim. The one correction vs the spec: `module-review` has no literal "security review" phrase to remove, so Step 5 is purely additive and the test pins only the positive references (matches the design's intent).

**Type/name consistency:** the sibling skill names asserted by `test-routing-discriminators.sh` (Step 1) exactly match the names added in Steps 3–10; the doc table and CHANGELOG name the same skills; bare (un-backticked) skill names are used in descriptions to match existing description style and the grep-based test.
