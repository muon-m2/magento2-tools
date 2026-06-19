# Design: `m2-*` slash-command shortcuts

**Status:** Approved (2026-06-17). Implementation plan written.

> **Post-review finalization** (after confirming plugin-command mechanics via `claude-code-guide`):
> - Plugin commands are **always namespaced** — invocation is `/magento2-tools:<name>`; there is
>   **no** unprefixed `/m2-<name>` form. The shortcut value is a shorter command name + `/`-picker
>   discoverability + a curated set, not a global short alias.
> - **Naming finalized to bare verbs** (prefix dropped, since the namespace already conveys
>   "magento2-tools"): `context`, `snapshot`, `review`, `security`, `perf`, `deploy`, `bugfix`,
>   `feature`, `release`. Read references to `m2-<name>` below as the bare verb.
> - **Write commands are user-only:** `deploy`, `bugfix`, `feature`, `release` set
>   `disable-model-invocation: true` so Claude can't auto-fire them; read-only commands stay
>   auto-invokable. §8 mechanics are now resolved (flat `commands/*.md`, auto-discovered;
>   `description`/`argument-hint`/`disable-model-invocation` frontmatter; `$ARGUMENTS` substitution).
**Scope:** the `magento2-tools` plugin. Adds a `commands/` surface (9 thin pass-through commands) + a contract test + docs. No skill changes.
**Author:** drafted via Claude Code for the magento2-tools plugin.

---

## 1. Why

The plugin is skills-only. The fastest way to invoke a skill today is the namespaced, verbose
`/magento2-tools:magento2-module-review …` (or relying on natural-language triggering). Short,
discoverable slash commands (`/m2-review …`) improve daily ergonomics and surface the common
operations in the `/` menu — without duplicating any skill logic.

## 2. Decisions (locked)

- **Set: 9 commands.** Read-only (5): `m2-context`, `m2-snapshot`, `m2-review`, `m2-security`,
  `m2-perf`. Write (4): `m2-deploy`, `m2-bugfix`, `m2-feature`, `m2-release`.
- **Thin pass-through.** Each command forwards `$ARGUMENTS` verbatim to its target skill via the
  Skill tool. No flags, gates, or behaviour are reimplemented.
- **Write shortcuts never weaken gates.** `m2-deploy`/`m2-bugfix`/`m2-feature`/`m2-release` route
  to skills that own approval/production gates; the command MUST NOT inject `--auto`,
  `--i-know-what-im-doing`, or otherwise bypass those gates. It forwards args only.
- **Naming:** short `m2-` prefix. Invoked `/magento2-tools:m2-<name>` (namespaced) and
  `/m2-<name>` when unambiguous.
- **`m2-snapshot` is the one fixed-mode command:** it routes to `magento2-debug` in **snapshot**
  mode, then forwards any extra args.

## 3. Command → skill mapping

| Command | Target skill | Fixed mode | Forwarded args (examples) |
|---|---|---|---|
| `/m2-context`  | `magento2-context`            | —        | `--no-cache` |
| `/m2-snapshot` | `magento2-debug`              | snapshot | `--since=`, `--save`, `--format=` |
| `/m2-review`   | `magento2-module-review`      | —        | `<module>`, `--diff [<ref>]`, `--format=`, `quick`, `--no-tier-3` |
| `/m2-security` | `magento2-security-audit`     | —        | `--scope=`, `--format=`, `--include-magento-core`, `<modules>` |
| `/m2-perf`     | `magento2-performance-audit`  | —        | `--runtime`, `--scope=`, `--format=`, `<modules>` |
| `/m2-deploy`   | `magento2-deploy`             | —        | `--env=`, `--validate-only`, `<modules>` (gates apply) |
| `/m2-bugfix`   | `magento2-bug-fix`            | —        | `"<desc>"`, `--module=`, `--log=` (RCA gate applies) |
| `/m2-feature`  | `magento2-feature-implement`  | —        | `"<request>"`, resume path (blueprint/plan gates apply) |
| `/m2-release`  | `magento2-release`            | —        | `--version=`, `--dry-run` ("type release" gate applies) |

## 4. Components / files

1. `commands/m2-<name>.md` × 9 — each: YAML frontmatter + a one-line pass-through body.
   - Frontmatter: `description` (shown in the `/` menu) and `argument-hint` (arg placeholder).
     *(Exact supported frontmatter keys for plugin commands are confirmed at plan time via the
     `command-development` skill — see §8.)*
   - Body: instructs invoking the named skill via the Skill tool with `$ARGUMENTS` forwarded
     (and the fixed mode for `m2-snapshot`), plus the "do not weaken gates" line for write commands.
2. `tests/test-command-routing.sh` — contract test (below).
3. Docs: README (Commands subsection + `commands/` layout line), `docs/skills-reference.md`
   (or sibling) command list, `CHANGELOG.md` `[Unreleased]`.

## 5. Pass-through body shape (illustrative — finalized in the plan)

A read-only command, e.g. `commands/m2-review.md`:

```markdown
---
description: Review a Magento 2 module/diff (magento2-module-review)
argument-hint: "[<Vendor>_<Module> | path] [--diff [<ref>]] [--format=json|sarif] [quick]"
---
Use the `magento2-tools:magento2-module-review` skill to review the target. Pass these
arguments through verbatim: $ARGUMENTS
```

A write command, e.g. `commands/m2-deploy.md`, adds one explicit safety line:

```markdown
Use the `magento2-tools:magento2-deploy` skill, forwarding $ARGUMENTS verbatim. Do not add
`--auto` or any gate-bypassing flag; the skill's approval and production gates apply unchanged.
```

`m2-snapshot` names the fixed mode:

```markdown
Use the `magento2-tools:magento2-debug` skill in **snapshot** mode, forwarding any extra
arguments: $ARGUMENTS
```

## 6. The contract test (`tests/test-command-routing.sh`)

For every `commands/*.md`:
- File has YAML frontmatter delimited by `---` with a non-empty `description`.
- The body references exactly one `magento2-<skill>` skill name, and that skill exists as a
  directory under `skills/` (catches typos / orphaned routes).
- The filename matches `m2-<kebab>.md`.
Then assert the set of command files equals the 9 expected names (no missing/extra).
SKIP (77) only if a required interpreter is missing; otherwise pure bash + grep. Runs in
`tests/run-all.sh`; must pass shellcheck `--severity=error`.

## 7. Error handling / non-goals

- The commands add no runtime logic, so the only failure mode is a mis-routed/typo'd skill name —
  caught by the contract test at CI time.
- **Non-goal:** changing any skill, flag, or gate. Commands are aliases, not new behaviour.
- **Non-goal:** a shortcut for every skill — only the 9 chosen high-frequency entry points (YAGNI).
- **Non-goal:** bypassing or streamlining any approval/production gate.

## 8. Implementation-time verification (confirm, don't assume)

Resolved at plan time via the `command-development` skill / Claude Code docs:
- The plugin **command file location** (`commands/` at plugin root) and discovery.
- Supported **frontmatter keys** (`description`, `argument-hint`, and whether `allowed-tools` /
  `model` are useful here — default: omit).
- **Argument substitution** token (`$ARGUMENTS` vs `$1`/`$2`) and how it reaches the prompt.
- **Namespacing/invocation** (`/magento2-tools:m2-<name>` and short `/m2-<name>`), and that a
  command can reliably drive the Skill tool from its body.

If any mechanic differs, only the command-file frontmatter/body shape (§5) adapts; the set (§2/§3),
the test (§6), and the docs (§4) are unaffected.

## 9. Versioning & docs

- New plugin surface (commands) → CHANGELOG `[Unreleased]` entry; a minor plugin bump at the next
  release. README gains a Commands subsection + a `commands/` layout line. No skill-version changes.
