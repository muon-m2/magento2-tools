# Design: `.docs/` path-guard PreToolUse hook

**Status:** Approved design (2026-06-17) — pending spec review, then implementation plan.
**Scope:** the `magento2-tools` plugin. Adds a `PreToolUse` hook (a new plugin surface).
**Author:** drafted via Claude Code for the magento2-tools plugin.

---

## 1. Why

`magento2-context` carries a strongly-worded invariant (its Core Rules):

> All `.docs/` artifacts produced by any `magento2-*` skill are written under
> `{project_root}/.docs/` … Never write `.docs/` under `{magento_root}`, `app/code`, or
> any module directory, even if a step changes the shell's cwd.

Today this is **prose the model must remember**. The realistic failure mode: a skill changes
the shell's cwd into `src/` or a module directory mid-run and writes `.docs/report.md` there,
landing the artifact at `src/.docs/` or `app/code/Vendor/Module/.docs/` instead of the project
root. A `PreToolUse` hook converts the invariant into a **hard, mechanical guarantee** the model
cannot violate.

## 2. Decisions (locked)

- **Enforcement:** hard **block**, no escape hatch. A misplaced `.docs/` write is denied, period.
- **Consequence of no escape hatch:** the matcher MUST NOT produce false positives. The design
  therefore **fails open** on every uncertain branch and denies **only** on a fully-determined
  violation.
- **Matcher approach (A):** a pure path rule keyed off `CLAUDE_PROJECT_DIR`. No dependency on the
  `magento2-context` cache (it is often absent/stale; the invariant is fully expressible as a path
  rule).
- **Scope gate:** the hook is a **no-op unless a Magento project is detected**, so it is safe at
  `--scope user` install across all of a user's repos.
- **Tools watched:** `Write` and `Edit`.

## 3. The matcher rule

Let `R` = normalized `CLAUDE_PROJECT_DIR`. Let `P` = the target file, resolved to an absolute,
lexically-normalized path (relative paths resolved against the hook input's `cwd`; `.`/`..`
collapsed; existence not required, since `Write` creates new files).

```
ALLOW  if  tool_name ∉ {Write, Edit}
ALLOW  if  no file_path in tool_input
ALLOW  if  CLAUDE_PROJECT_DIR is unset/empty
ALLOW  if  the project is NOT a Magento project (scope gate)
ALLOW  if  P has no path segment exactly equal to ".docs"
ALLOW  if  P is NOT inside R
ALLOW  if  P is inside  R + "/.docs/"   (or P == R + "/.docs")   ← the canonical location
DENY   otherwise
```

"DENY otherwise" is reached only when: Magento project **and** `P` is inside `R` **and** `P`
contains a `.docs` segment **and** that `.docs` is not the top-level `{R}/.docs`. That is exactly
the misplaced-artifact case the invariant forbids (`src/.docs/…`, `app/code/**/.docs/…`,
`vendor/**/.docs/…`, etc.).

This rule handles both repo layouts: Magento at root (`R/app/code/**/.docs` denied; `R/.docs`
allowed) and Magento under `src/` (`R/src/.docs` denied; `R/.docs` allowed).

### Magento-project detection (scope gate)

A project is "Magento" if any of these exist (cheap filesystem checks on `R`):

- `R/bin/magento`
- `R/app/etc/` (directory)
- `R/src/bin/magento`
- `R/src/app/etc/` (directory)
- `R/composer.json` containing the substring `magento/`

Otherwise the hook exits 0 (allow) immediately.

## 4. Components

1. **`hooks/guard-docs-path.sh`** — the hook entry point.
   - Reads the `PreToolUse` JSON from stdin; extracts `tool_name`, `tool_input.file_path`, and
     `cwd` via `python3`. **Fails open (exit 0) if `python3` is unavailable** — a robustness
     fallback, not a user escape hatch.
   - Determines `R` from `CLAUDE_PROJECT_DIR`, applies the scope gate, resolves `P`, and runs the
     matcher.
   - On DENY, emits the `PreToolUse` deny decision with a reason message that names the
     `magento2-context` rule and the correct location (`{project_root}/.docs/`).
2. **The matcher** — a pure shell function `decide <project_root> <abs_path> <is_magento>` printing
   `allow` or `deny`, with **no I/O of its own**, so the contract test can drive it directly.
3. **Hook registration** — the plugin's hooks configuration registering
   `hooks/guard-docs-path.sh` for `PreToolUse` matching `Write|Edit`.
4. **`tests/test-docs-path-guard.sh`** — a table-driven contract test of the matcher.

## 5. Test matrix (contract test)

| Target path | Magento? | `CLAUDE_PROJECT_DIR` set? | Verdict |
|---|---|---|---|
| `{R}/.docs/review.md` | yes | yes | allow |
| `{R}/.docs/sub/x.md` | yes | yes | allow |
| `{R}/src/.docs/review.md` | yes | yes | **deny** |
| `{R}/app/code/Acme/Mod/.docs/x.md` | yes | yes | **deny** |
| `{R}/vendor/foo/.docs/x.md` | yes | yes | **deny** |
| `{R}/app/code/Acme/Mod/etc/di.xml` | yes | yes | allow (no `.docs`) |
| `{R}/notdocs/.docs/x.md` | yes | yes | **deny** |
| `{R}/src/.docs/x.md` | **no** | yes | allow (scope gate off) |
| `/tmp/outside/.docs/x.md` | yes | yes | allow (outside project root) |
| `{R}/.docs/x.md` | yes | **no** | allow (fail-open) |

The test exercises the pure matcher with explicit `(project_root, abs_path, is_magento)` tuples;
it does not need to build JSON or run a live Magento install. It runs inside `tests/run-all.sh`
and must pass shellcheck under CI's `--severity=error`.

## 6. Error handling

Every uncertain branch allows (§3). The single route to a denial is the fully-determined
violation. There is no state, no network, no cache read — the hook is a deterministic function of
`(tool_name, file_path, cwd, CLAUDE_PROJECT_DIR, filesystem markers)`.

## 7. Out of scope / non-goals

- Not an adversarial control: symlink trickery or absolute paths crafted to dodge the rule are not
  defended against. The hook guards **accidental misplacement by skills**, not a malicious actor.
- Does not read or depend on `.claude/.cache/magento2-context.json`.
- Does not warn-or-relocate; it only allows or denies (relocation stays the skill's job).
- Does not watch read tools or `NotebookEdit` (`.docs/` artifacts are markdown written via
  `Write`/`Edit`).

## 8. Implementation-time verification (must confirm against current docs, not assumed)

The exact Claude Code **plugin hook wiring** must be verified before/while implementing — these
are the only unknowns and will be confirmed via the `plugin-dev:hook-development` guidance /
`claude-code-guide`, not guessed:

- The hooks config **file location and schema** for a plugin (e.g. `hooks/hooks.json` vs a key in
  `plugin.json`), and how `${CLAUDE_PLUGIN_ROOT}` is referenced for the script path.
- The `PreToolUse` **deny mechanism**: JSON `permissionDecision: "deny"` output vs. exit-code-2 +
  stderr — and the exact JSON shape (`hookSpecificOutput.hookEventName` etc.).
- That `CLAUDE_PROJECT_DIR` and the stdin `cwd` field are available to plugin `PreToolUse` hooks.

If any mechanism differs from the above, the matcher (§3) is unaffected — only Component 1's I/O
and Component 3's registration adapt.

## 9. Versioning & docs

- New plugin surface → note in `CHANGELOG.md` under an Unreleased entry and add a `hooks/` line to
  the README layout. Minor version bump when next released (not part of this change).
- No skill-version registry entry (this is a plugin-level hook, not a skill).
