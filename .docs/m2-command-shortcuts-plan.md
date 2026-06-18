# `magento2-tools` Slash-Command Shortcuts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 9 thin pass-through slash commands (`/magento2-tools:<verb>`) that forward arguments to the matching skill, improving discoverability/ergonomics without changing any skill behaviour.

**Architecture:** A new auto-discovered `commands/` directory at the plugin root holds one flat `<verb>.md` per command: YAML frontmatter (`description`, `argument-hint`, and for write commands `disable-model-invocation: true`) + a one-line body instructing the matching `magento2-tools:magento2-<skill>` skill to run with `$ARGUMENTS`. A contract test pins every command to a real skill. No skill files change.

**Tech Stack:** Markdown command files (Claude Code plugin commands), bash + grep contract test, the repo's `tests/run-all.sh` harness.

**Reference:** design spec `.docs/m2-command-shortcuts-design.md`. Plugin-command mechanics confirmed via `claude-code-guide`: flat `commands/*.md` auto-discovered; always invoked `/magento2-tools:<name>`; `$ARGUMENTS` substitution; `description`/`argument-hint`/`disable-model-invocation` frontmatter.

---

### Task 1: The 9 command files + contract test (TDD)

**Files:**
- Create: `tests/test-command-routing.sh`
- Create: `commands/{context,snapshot,review,security,perf,deploy,bugfix,feature,release}.md`

- [ ] **Step 1: Write the contract test.** Create `tests/test-command-routing.sh`:

```bash
#!/usr/bin/env bash
# test-command-routing.sh — every commands/*.md must be a well-formed thin pass-through to a
# real magento2-* skill, and the set must be exactly the 9 expected shortcuts. Write commands
# must be user-only (disable-model-invocation: true).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CMD_DIR="commands"
FAIL=0

# expected: command verb -> target skill
EXPECTED="context:magento2-context
snapshot:magento2-debug
review:magento2-module-review
security:magento2-security-audit
perf:magento2-performance-audit
deploy:magento2-deploy
bugfix:magento2-bug-fix
feature:magento2-feature-implement
release:magento2-release"

if [ ! -d "$CMD_DIR" ]; then echo "FAIL: $CMD_DIR/ directory not found"; exit 1; fi

# 1. each expected command exists, is well-formed, and routes to its (real) skill
while IFS=: read -r cmd skill; do
    [ -n "$cmd" ] || continue
    f="$CMD_DIR/$cmd.md"
    if [ ! -f "$f" ]; then echo "FAIL: missing command file $f"; FAIL=1; continue; fi
    [ "$(head -1 "$f")" = "---" ] || { echo "FAIL: $f missing YAML frontmatter"; FAIL=1; }
    grep -qE '^description: +.+' "$f" || { echo "FAIL: $f missing non-empty description"; FAIL=1; }
    grep -q "magento2-tools:$skill" "$f" || { echo "FAIL: $f does not route to magento2-tools:$skill"; FAIL=1; }
    [ -d "skills/$skill" ] || { echo "FAIL: $f routes to non-existent skill $skill"; FAIL=1; }
done <<EOF
$EXPECTED
EOF

# 2. write commands must be user-only
for cmd in deploy bugfix feature release; do
    f="$CMD_DIR/$cmd.md"
    [ -f "$f" ] || continue
    grep -qE '^disable-model-invocation: +true' "$f" \
        || { echo "FAIL: write command $f must set 'disable-model-invocation: true'"; FAIL=1; }
done

# 3. no unexpected command files, and filenames are lowercase-kebab
for f in "$CMD_DIR"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    printf '%s\n' "$EXPECTED" | grep -q "^$base:" \
        || { echo "FAIL: unexpected command file $f (not in expected set)"; FAIL=1; }
    printf '%s' "$base" | grep -qE '^[a-z][a-z0-9-]*$' \
        || { echo "FAIL: $f filename not lowercase-kebab"; FAIL=1; }
done

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "command routing: 9 commands valid, well-formed, routed to real skills"
exit 0
```

- [ ] **Step 2: Run the test to verify it FAILS (RED).**

Run: `bash tests/test-command-routing.sh`
Expected: FAIL — `commands/ directory not found` (exit 1), since no commands exist yet.

- [ ] **Step 3: Create the 5 read-only command files.** (Read-only commands omit `disable-model-invocation`, so they default to auto-invokable.)

`commands/context.md`:
```markdown
---
description: Resolve the Magento 2 project context — vendor, runner, versions, theme, tools (magento2-context)
argument-hint: "[--no-cache]"
---
Use the `magento2-tools:magento2-context` skill to resolve and emit the project context. Forward these arguments verbatim: $ARGUMENTS
```

`commands/snapshot.md`:
```markdown
---
description: One-page Magento 2 health snapshot — indexers, caches, queues, cron, versions (magento2-debug)
argument-hint: "[--since=<dur>] [--save] [--format=<fmt>]"
---
Use the `magento2-tools:magento2-debug` skill in **snapshot** mode. Forward any additional arguments verbatim: $ARGUMENTS
```

`commands/review.md`:
```markdown
---
description: Review a Magento 2 module or diff against standards (magento2-module-review)
argument-hint: "<Vendor>_<Module> | <path> [--diff [<ref>]] [--format=json|sarif] [quick]"
---
Use the `magento2-tools:magento2-module-review` skill to review the requested target. Forward these arguments verbatim: $ARGUMENTS
```

`commands/security.md`:
```markdown
---
description: Security audit — CVEs, secrets, EQP static rules, cross-module patterns (magento2-security-audit)
argument-hint: "[--scope=module|site|vendor] [--format=markdown|json|sarif] [--include-magento-core] [<modules>…]"
---
Use the `magento2-tools:magento2-security-audit` skill. Forward these arguments verbatim: $ARGUMENTS
```

`commands/perf.md`:
```markdown
---
description: Performance audit — N+1, caching, indexer/queue review (magento2-performance-audit)
argument-hint: "[--runtime] [--scope=module|site] [--format=markdown|json|sarif] [<modules>…]"
---
Use the `magento2-tools:magento2-performance-audit` skill. Forward these arguments verbatim: $ARGUMENTS
```

- [ ] **Step 4: Create the 4 write command files.** (Each sets `disable-model-invocation: true` and carries an explicit "don't weaken gates" line.)

`commands/deploy.md`:
```markdown
---
description: Deploy Magento 2 module(s) — pre-flight, ordered deploy, rollback (magento2-deploy)
argument-hint: "[--env=local|staging|production] [--validate-only] <modules>…"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-deploy` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not add `--auto`, `--i-know-what-im-doing`, or any other gate-bypassing flag. The skill's approval gate and production double-gate apply unchanged.
```

`commands/bugfix.md`:
```markdown
---
description: Reproduce → root-cause → minimal TDD fix → regression test → review (magento2-bug-fix)
argument-hint: "\"<bug description>\" [--module=…] [--log=…] [--severity=…]"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-bug-fix` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not skip reproduction/RCA or the RCA approval gate; the skill's normal flow applies.
```

`commands/feature.md`:
```markdown
---
description: End-to-end Magento 2 feature implementation orchestrator (magento2-feature-implement)
argument-hint: "\"<feature request>\" | resume ./.docs/<FeatureName>"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-feature-implement` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not bypass the blueprint or task-plan approval gates; the skill's normal flow applies.
```

`commands/release.md`:
```markdown
---
description: Release a Magento 2 module — version bump, changelog, tag, publish (magento2-release)
argument-hint: "[--version=X.Y.Z] [--no-publish] [--no-github-release] [--dry-run]"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-release` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not bypass the release confirmation gate; the skill waits for an explicit "release".
```

- [ ] **Step 5: Run the test to verify it PASSES (GREEN), plus the full suite.**

Run: `bash tests/test-command-routing.sh`
Expected: `command routing: 9 commands valid, well-formed, routed to real skills`, exit 0.

Run: `bash tests/run-all.sh`
Expected: a `PASS:` line with `FAIL: 0`, `test-command-routing.sh` shown as PASS, and **no** regression in `test-reference-integrity.sh` / `test-skill-count-consistency.sh` (the new files reference skill *invocation names*, not file paths, and contain no "N skills" prose). If `test-reference-integrity.sh` fails on the new `commands/`, STOP and report — do not loosen a command body; surface the exact rule it tripped.

- [ ] **Step 6: shellcheck the new test if available.**

Run: `command -v shellcheck >/dev/null && shellcheck --severity=error --exclude=SC1091 tests/test-command-routing.sh && echo CLEAN || echo "shellcheck absent — CI runs it"`
Expected: `CLEAN` or the absent note.

- [ ] **Step 7: Commit.**

```bash
chmod +x tests/test-command-routing.sh
git add commands tests/test-command-routing.sh
git commit -m "feat(commands): add 9 magento2-tools slash-command shortcuts + routing test"
```

---

### Task 2: Documentation

**Files:**
- Modify: `README.md` (layout block + new Commands section)
- Modify: `CHANGELOG.md` (new `[Unreleased]` section)

- [ ] **Step 1: Add a `commands/` line to the README layout block.** Use the Edit tool:

OLD:
```
skills/              # 18 magento2-* skills (auto-discovered by Claude Code)
hooks/               # PreToolUse guard: keeps .docs/ artifacts at the project root
```
NEW:
```
skills/              # 18 magento2-* skills (auto-discovered by Claude Code)
commands/            # 9 /magento2-tools:<verb> shortcut commands (auto-discovered)
hooks/               # PreToolUse guard: keeps .docs/ artifacts at the project root
```

(If the OLD two-line block isn't found verbatim, STOP and report NEEDS_CONTEXT.)

- [ ] **Step 2: Add a Commands section to the README.** Insert this block immediately BEFORE the line `## Per-project environment overrides` (Edit: prepend it to that heading):

```markdown
## Commands

Thin slash-command shortcuts for common operations. Each forwards your arguments verbatim to the
underlying skill — no behaviour changes, and the write commands keep every approval/production
gate. They are always namespaced:

| Command | Routes to | Use |
|---------|-----------|-----|
| `/magento2-tools:context`  | `magento2-context` | resolve project context (`--no-cache`) |
| `/magento2-tools:snapshot` | `magento2-debug` (snapshot) | one-page health snapshot |
| `/magento2-tools:review`   | `magento2-module-review` | review a module / `--diff` |
| `/magento2-tools:security` | `magento2-security-audit` | security audit |
| `/magento2-tools:perf`     | `magento2-performance-audit` | performance audit |
| `/magento2-tools:deploy`   | `magento2-deploy` | deploy (gated) |
| `/magento2-tools:bugfix`   | `magento2-bug-fix` | reproduce → RCA → fix (gated) |
| `/magento2-tools:feature`  | `magento2-feature-implement` | feature orchestrator (gated) |
| `/magento2-tools:release`  | `magento2-release` | cut a release (gated) |

The four write commands (`deploy`, `bugfix`, `feature`, `release`) are user-invoked only; the
read-only five may also be auto-suggested. All arguments/flags are passed straight through to the
skill, which is the source of truth for behaviour and gates.

```

(Anchor `## Per-project environment overrides` exists once in the README. If not found, STOP and report NEEDS_CONTEXT.)

- [ ] **Step 3: Add a CHANGELOG `[Unreleased]` section.** Since v1.8.0 was just released, the CHANGELOG currently has no `[Unreleased]`. Insert one between the Semantic-Versioning line and `## [1.8.0]`. Edit:

OLD:
```
This project adheres to [Semantic Versioning](https://semver.org/).

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```
NEW:
```
This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Slash-command shortcuts** — a `commands/` surface with 9 thin pass-through commands
  (`/magento2-tools:context|snapshot|review|security|perf|deploy|bugfix|feature|release`) that
  forward arguments verbatim to the matching skill. Read-only commands are auto-invokable; the
  four write commands (`deploy`/`bugfix`/`feature`/`release`) are user-only
  (`disable-model-invocation: true`) and never weaken a skill's approval/production gates.
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```

(If the OLD block isn't found verbatim, STOP and report NEEDS_CONTEXT.)

- [ ] **Step 4: Verify and commit.**

Run: `grep -n 'commands/' README.md | head -2 && grep -n '## Commands' README.md && grep -n 'Unreleased' CHANGELOG.md && bash tests/run-all.sh | tail -3`
Expected: the layout `commands/` line + the `## Commands` heading in README; `## [Unreleased]` in CHANGELOG; suite `FAIL: 0`.

```bash
git add README.md CHANGELOG.md
git commit -m "docs(commands): document slash-command shortcuts (README + CHANGELOG)"
```

---

### Task 3: Final verification

- [ ] **Step 1: Full suite + clean tree.**

Run: `bash tests/run-all.sh | tail -4 && git status --short`
Expected: `FAIL: 0` with `test-command-routing.sh` PASS; `git status` shows only the pre-existing untracked `.gitignore`/`.claude/`/`.docs/` — nothing stray.

- [ ] **Step 2: Scope check.**

Run: `git diff --stat 61b9628..HEAD -- skills/`
Expected: EMPTY — no skill file changed. Then `git diff --stat $(git merge-base HEAD main)..HEAD` should list only `commands/*.md` (9), `tests/test-command-routing.sh`, `README.md`, `CHANGELOG.md`.

- [ ] **Step 3: Sanity — every command names a real skill that exists on disk.**

Run:
```bash
for f in commands/*.md; do
  s=$(grep -oE 'magento2-tools:magento2-[a-z-]+' "$f" | head -1 | sed 's/magento2-tools://')
  [ -d "skills/$s" ] && echo "ok  $(basename "$f") -> $s" || echo "BAD $(basename "$f") -> $s"
done
```
Expected: 9 `ok` lines, no `BAD`.

---

## Self-review

**Spec coverage** (`.docs/m2-command-shortcuts-design.md`):
- §2/§3 set + mapping (9 bare-verb commands, snapshot fixed-mode, write user-only) → Task 1 Steps 3–4.
- §4/§5 thin pass-through frontmatter + body → the verbatim files in Task 1.
- §6 contract test → Task 1 Step 1 (`test-command-routing.sh`).
- §8 mechanics (resolved) → applied: flat `commands/*.md`, `description`/`argument-hint`/`disable-model-invocation`, `$ARGUMENTS`, `/magento2-tools:<name>`.
- §9 docs → Task 2 (README layout + Commands section + CHANGELOG); skill-count test unaffected (no "N skills" prose added).
- Safety (write gates not weakened) → explicit lines in each write command + the user-only test check.

**Placeholder scan:** command files and the test are verbatim; the one explicit NOTE tells the implementer to remove the stray `placeholder no-op` line from the test loop (an intentional cleanup instruction, not a plan placeholder). Docs give exact old/new strings.

**Type/name consistency:** the 9 verbs and their target skills are identical across the test's `EXPECTED` map, the command files, the README table, and the CHANGELOG entry; `disable-model-invocation: true` appears in exactly the four write files and is checked for exactly those four.
