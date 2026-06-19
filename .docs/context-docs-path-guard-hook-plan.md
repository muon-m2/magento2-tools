# `.docs/` Path-Guard Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `PreToolUse` hook that blocks `Write`/`Edit` of `.docs/` artifacts anywhere other than `{project_root}/.docs/` in a detected Magento project, turning the `magento2-context` artifact-location rule into a hard guarantee.

**Architecture:** A pure, argument-driven decision function (`hooks/docs-path-matcher.sh`) does the string logic and is unit-tested directly; a thin entry script (`hooks/guard-docs-path.sh`) parses the `PreToolUse` JSON, applies the Magento scope gate, and calls the matcher, denying via exit code 2. Registered in `hooks/hooks.json`. Fails open on every uncertainty (no escape hatch ⇒ no false positives).

**Tech Stack:** Bash (3.2-compatible: `read -d ''`, no `mapfile`), `python3` for JSON parsing + path normalization (hook fails open if absent), the repo's existing `tests/run-all.sh` contract harness, GitHub Actions shellcheck.

**Reference:** design spec at `.docs/context-docs-path-guard-hook-design.md`.

---

### Task 1: Pure matcher + unit tests (TDD)

**Files:**
- Create: `hooks/docs-path-matcher.sh`
- Create: `tests/test-docs-path-guard.sh`

- [ ] **Step 1: Write the failing test (matcher cases only)**

Create `tests/test-docs-path-guard.sh`:

```bash
#!/usr/bin/env bash
# test-docs-path-guard.sh — the .docs/ path guard's matcher (and, when python3 is present,
# the entry script end-to-end). Matcher cases need no interpreter and always run.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=../hooks/docs-path-matcher.sh
. hooks/docs-path-matcher.sh

FAIL=0
R=/proj

m() { # desc expected root path is_magento
    local desc="$1" expected="$2" got
    got="$(docs_path_decide "$3" "$4" "$5")"
    if [ "$got" = "$expected" ]; then
        printf '  ok   matcher: %s\n' "$desc"
    else
        printf '  FAIL matcher: %s — expected %s got %s\n' "$desc" "$expected" "$got"
        FAIL=1
    fi
}

echo "matcher unit cases:"
m "canonical {root}/.docs"        allow "$R" "$R/.docs/review.md"               yes
m "nested under {root}/.docs"     allow "$R" "$R/.docs/sub/x.md"                yes
m "{root}/.docs itself"           allow "$R" "$R/.docs"                         yes
m "src/.docs misplaced"           deny  "$R" "$R/src/.docs/review.md"           yes
m "module .docs misplaced"        deny  "$R" "$R/app/code/Acme/Mod/.docs/x.md"  yes
m "vendor .docs misplaced"        deny  "$R" "$R/vendor/foo/.docs/x.md"         yes
m "notdocs/.docs misplaced"       deny  "$R" "$R/notdocs/.docs/x.md"            yes
m "non-.docs path"                allow "$R" "$R/app/code/Acme/Mod/etc/di.xml"  yes
m "filename containing .docs"     allow "$R" "$R/notes.docs"                    yes
m "scope gate off (non-magento)"  allow "$R" "$R/src/.docs/x.md"                no
m "outside project root"          allow "$R" "/tmp/out/.docs/x.md"              yes

if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
exit 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test-docs-path-guard.sh`
Expected: FAIL — `hooks/docs-path-matcher.sh: No such file or directory` (the `.` source line errors because the matcher does not exist yet).

- [ ] **Step 3: Write the matcher**

Create `hooks/docs-path-matcher.sh`:

```bash
#!/usr/bin/env bash
# docs-path-matcher.sh — pure decision function for the .docs/ path guard.
#
#   docs_path_decide <project_root> <abs_path> <is_magento>   -> echoes "allow" | "deny"
#
# Inputs are pre-normalized: project_root has no trailing slash; abs_path is absolute and
# lexically normalized; is_magento is "yes" or "no". No I/O, no globals — directly testable.
# Fails OPEN (allow) on every branch except a fully-determined misplaced-.docs write.

docs_path_decide() {
    local root="$1" path="$2" is_magento="$3"

    # Scope gate: only Magento projects are governed by the .docs/ convention.
    [ "$is_magento" = "yes" ] || { printf 'allow\n'; return 0; }

    # Must be strictly inside the project root.
    case "$path" in
        "$root"/*) ;;
        *) printf 'allow\n'; return 0 ;;
    esac

    # Must contain a path segment exactly equal to ".docs".
    case "/$path/" in
        */.docs/*) ;;
        *) printf 'allow\n'; return 0 ;;
    esac

    # Canonical allowed location: {root}/.docs and anything beneath it.
    if [ "$path" = "$root/.docs" ]; then printf 'allow\n'; return 0; fi
    case "$path" in
        "$root"/.docs/*) printf 'allow\n'; return 0 ;;
    esac

    # Magento project, inside root, has a .docs segment, not the canonical one -> block.
    printf 'deny\n'
    return 0
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-docs-path-guard.sh`
Expected: PASS — all 11 matcher lines print `ok`, final line `RESULT: PASS`.

- [ ] **Step 5: Commit**

```bash
chmod +x tests/test-docs-path-guard.sh
git add hooks/docs-path-matcher.sh tests/test-docs-path-guard.sh
git commit -m "feat(hooks): add pure .docs/ path-guard matcher + unit tests"
```

---

### Task 2: Hook entry script + entry-script integration tests (TDD)

**Files:**
- Create: `hooks/guard-docs-path.sh`
- Modify: `tests/test-docs-path-guard.sh` (append the integration block before the final result check)

- [ ] **Step 1: Add the failing integration block to the test**

In `tests/test-docs-path-guard.sh`, insert this block **immediately before** the final
`if [ "$FAIL" -ne 0 ]` result check:

```bash
# Entry-script integration (needs python3; matcher cases above already ran).
if command -v python3 >/dev/null 2>&1; then
    echo "entry-script integration cases:"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/bin"; : > "$tmp/bin/magento"   # mark $tmp as a Magento project

    mkjson() { # tool path cwd
        python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{"file_path":sys.argv[2]},"cwd":sys.argv[3]}))' "$1" "$2" "$3"
    }
    e() { # desc want_exit tool path [cwd]
        local desc="$1" want="$2" tool="$3" path="$4" cwd="${5:-$tmp}" rc=0
        CLAUDE_PROJECT_DIR="$tmp" bash hooks/guard-docs-path.sh <<<"$(mkjson "$tool" "$path" "$cwd")" >/dev/null 2>&1 || rc=$?
        if [ "$rc" = "$want" ]; then
            printf '  ok   entry: %s (exit %s)\n' "$desc" "$rc"
        else
            printf '  FAIL entry: %s — expected exit %s got %s\n' "$desc" "$want" "$rc"
            FAIL=1
        fi
    }

    e "Write canonical .docs allowed"    0 Write "$tmp/.docs/r.md"
    e "Write src/.docs blocked"          2 Write "$tmp/src/.docs/r.md"
    e "Write module .docs blocked"       2 Write "$tmp/app/code/A/M/.docs/x.md"
    e "Edit non-.docs allowed"           0 Edit  "$tmp/app/code/A/M/etc/di.xml"
    e "Write relative src/.docs blocked" 2 Write "src/.docs/r.md"
    e "non-Write/Edit tool ignored"      0 Read  "$tmp/src/.docs/r.md"

    # Non-Magento project: the same misplaced path must be allowed.
    tmp2="$(mktemp -d)"; rc2=0
    CLAUDE_PROJECT_DIR="$tmp2" bash hooks/guard-docs-path.sh \
        <<<"$(mkjson Write "$tmp2/src/.docs/x.md" "$tmp2")" >/dev/null 2>&1 || rc2=$?
    if [ "$rc2" = 0 ]; then printf '  ok   entry: non-magento misplaced allowed (exit 0)\n'
    else printf '  FAIL entry: non-magento expected 0 got %s\n' "$rc2"; FAIL=1; fi
    rm -rf "$tmp2"

    # Fail-open: no CLAUDE_PROJECT_DIR -> allow even a misplaced path.
    rc3=0
    env -u CLAUDE_PROJECT_DIR bash hooks/guard-docs-path.sh \
        <<<"$(mkjson Write /x/src/.docs/x.md /x)" >/dev/null 2>&1 || rc3=$?
    if [ "$rc3" = 0 ]; then printf '  ok   entry: fail-open without project dir (exit 0)\n'
    else printf '  FAIL entry: fail-open expected 0 got %s\n' "$rc3"; FAIL=1; fi
else
    echo "entry-script integration: SKIP (python3 not on PATH); matcher cases ran"
fi
```

- [ ] **Step 2: Run the test to verify the new block fails**

Run: `bash tests/test-docs-path-guard.sh`
Expected: matcher cases PASS; entry cases FAIL (e.g. `Write src/.docs blocked — expected exit 2 got 127`, because `hooks/guard-docs-path.sh` does not exist yet → `bash` can't open it). Final `RESULT: FAIL`.

- [ ] **Step 3: Write the entry script**

Create `hooks/guard-docs-path.sh`:

```bash
#!/usr/bin/env bash
# guard-docs-path.sh — PreToolUse guard enforcing the magento2-context .docs/ rule.
#
# Blocks Write/Edit of a .docs/ artifact anywhere other than {CLAUDE_PROJECT_DIR}/.docs/
# in a detected Magento project. Fails OPEN (exit 0) on any uncertainty: missing python3,
# missing CLAUDE_PROJECT_DIR, unparseable input, non-Write/Edit tool, no file_path, a
# non-Magento repo, or a path outside the project root. A confirmed misplaced .docs/ write
# is denied with exit code 2 (the documented PreToolUse block). There is no escape hatch by
# design, so every uncertain branch allows.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./docs-path-matcher.sh
. "$HERE/docs-path-matcher.sh"

# Fail open if python3 is unavailable (robustness fallback, not a user escape hatch).
command -v python3 >/dev/null 2>&1 || exit 0

# Project root from the environment; fail open if absent. Strip any trailing slash.
project_root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$project_root" ] || exit 0
project_root="${project_root%/}"

input="$(cat)"

# Parse tool_name + resolve an absolute, normalized file_path. NUL-delimited so paths with
# spaces survive; python3 prints nothing on bad JSON -> fields stay empty -> allow.
tool_name=""; file_path=""
{
    IFS= read -r -d '' tool_name || true
    IFS= read -r -d '' file_path || true
} < <(
    CLAUDE_PROJECT_DIR="$project_root" python3 - "$input" <<'PY' 2>/dev/null || true
import json, os, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
tn = d.get("tool_name") or ""
ti = d.get("tool_input")
fp = ti.get("file_path") if isinstance(ti, dict) else ""
fp = fp or ""
cwd = d.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR", "")
if fp and not os.path.isabs(fp):
    fp = os.path.join(cwd, fp)
fp = os.path.normpath(fp) if fp else ""
sys.stdout.write(tn + "\0" + fp + "\0")
PY
)

# Only governs file-writing tools.
case "$tool_name" in
    Write|Edit) ;;
    *) exit 0 ;;
esac
[ -n "$file_path" ] || exit 0

# Scope gate: is this a Magento project? (cheap filesystem markers, both repo layouts)
is_magento=no
if [ -e "$project_root/bin/magento" ] || [ -d "$project_root/app/etc" ] \
   || [ -e "$project_root/src/bin/magento" ] || [ -d "$project_root/src/app/etc" ] \
   || { [ -f "$project_root/composer.json" ] && grep -q 'magento/' "$project_root/composer.json"; }; then
    is_magento=yes
fi

if [ "$(docs_path_decide "$project_root" "$file_path" "$is_magento")" = "deny" ]; then
    rel="${file_path#"$project_root"/}"
    {
        echo "magento2-tools: blocked writing a .docs/ artifact at '$rel'."
        echo "All .docs/ artifacts must live at the project root: $project_root/.docs/"
        echo "(magento2-context Core Rules: never write .docs/ under the Magento tree)."
    } >&2
    exit 2
fi
exit 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-docs-path-guard.sh`
Expected: PASS — matcher cases `ok`, entry cases `ok` (including both `exit 2` blocks and the fail-open `exit 0`), final `RESULT: PASS`.

- [ ] **Step 5: Commit**

```bash
chmod +x hooks/guard-docs-path.sh
git add hooks/guard-docs-path.sh tests/test-docs-path-guard.sh
git commit -m "feat(hooks): add PreToolUse .docs/ path-guard entry script + integration tests"
```

---

### Task 3: Register the hook

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write the plugin hooks config**

Create `hooks/hooks.json` (plugin wrapper format; `${CLAUDE_PLUGIN_ROOT}` for portability):

```json
{
  "description": "magento2-tools: block Write/Edit of .docs/ artifacts outside the project-root .docs/ directory (magento2-context artifact-location rule).",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-docs-path.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate the JSON**

Run: `python3 -c "import json; json.load(open('hooks/hooks.json')); print('hooks.json OK')"`
Expected: `hooks.json OK`

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat(hooks): register PreToolUse .docs/ guard in hooks/hooks.json"
```

---

### Task 4: Extend syntax/lint coverage to `hooks/`

**Files:**
- Modify: `tests/test-bash-syntax.sh:13`
- Modify: `.github/workflows/tests.yml:20`

- [ ] **Step 1: Extend the bash-syntax contract test to scan `hooks/`**

In `tests/test-bash-syntax.sh`, replace the find on line 13:

Old:
```bash
done < <(find skills -path '*/scripts/*.sh' -type f)
```
New:
```bash
done < <(find skills -path '*/scripts/*.sh' -type f; find hooks -name '*.sh' -type f 2>/dev/null)
```

Also update the header comment on line 2:

Old:
```bash
# Every script under skills/*/scripts/ must pass `bash -n`.
```
New:
```bash
# Every script under skills/*/scripts/ and hooks/ must pass `bash -n`.
```

- [ ] **Step 2: Extend CI shellcheck to scan `hooks/`**

In `.github/workflows/tests.yml`, replace the find on line 20:

Old:
```bash
          files=$(find skills tests -name '*.sh' -type f | sort)
```
New:
```bash
          files=$(find skills tests hooks -name '*.sh' -type f | sort)
```

- [ ] **Step 3: Verify bash syntax of the hook scripts and the extended test**

Run: `bash -n hooks/guard-docs-path.sh hooks/docs-path-matcher.sh && bash tests/test-bash-syntax.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK` (the contract test exits 0; no `syntax error in …` lines).

- [ ] **Step 4: Verify shellcheck locally if available (CI runs it regardless)**

Run: `command -v shellcheck >/dev/null && shellcheck --severity=error --exclude=SC1091 hooks/*.sh tests/test-docs-path-guard.sh && echo SHELLCHECK-CLEAN || echo "shellcheck absent — CI will run it"`
Expected: `SHELLCHECK-CLEAN` (or the absent note).

- [ ] **Step 5: Commit**

```bash
git add tests/test-bash-syntax.sh .github/workflows/tests.yml
git commit -m "test(ci): scan hooks/ in bash-syntax test and CI shellcheck"
```

---

### Task 5: Documentation

**Files:**
- Modify: `README.md` (Layout section)
- Modify: `CHANGELOG.md:8-9` (add an `[Unreleased]` section)

- [ ] **Step 1: Add `hooks/` to the README layout block**

In `README.md`, find the layout block line:
```
skills/              # 17 magento2-* skills (auto-discovered by Claude Code)
```
Insert immediately **after** it:
```
hooks/               # PreToolUse guard: keeps .docs/ artifacts at the project root
```
(Do not change the `17` count here — it is corrected separately on the
`chore/license-metadata-skill-count` branch / PR #12 to avoid a merge conflict.)

- [ ] **Step 2: Add an `[Unreleased]` CHANGELOG section**

In `CHANGELOG.md`, insert **between** line 7 (`This project adheres to …`) and line 9
(`## [1.7.0] …`):

```markdown

## [Unreleased]

### Added

- **`.docs/` path-guard hook** — a `PreToolUse` hook (`hooks/guard-docs-path.sh`, registered
  in `hooks/hooks.json`) that blocks `Write`/`Edit` of a `.docs/` artifact anywhere other than
  `{project_root}/.docs/` in a detected Magento project, enforcing the `magento2-context`
  artifact-location rule mechanically instead of by prose. No-op in non-Magento repos and on
  any uncertainty (fails open; no escape hatch). Pure matcher in `hooks/docs-path-matcher.sh`;
  contract test `tests/test-docs-path-guard.sh`. Plugin-level (not a skill) — no skill-version
  registry entry; a minor plugin version bump applies at the next release.
```

- [ ] **Step 3: Verify the docs edits**

Run: `grep -n 'hooks/' README.md && grep -n 'Unreleased' CHANGELOG.md`
Expected: one README hit for the new `hooks/` layout line; one CHANGELOG hit for `## [Unreleased]`.

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs(hooks): document the .docs/ path-guard hook (README layout + CHANGELOG)"
```

---

### Task 6: Full verification

- [ ] **Step 1: Run the whole contract harness**

Run: `bash tests/run-all.sh`
Expected: a `PASS:` line with `FAIL: 0`; `test-docs-path-guard.sh` and `test-bash-syntax.sh`
both `PASS`. (Skips are acceptable only where an interpreter is genuinely missing.)

- [ ] **Step 2: Confirm no unintended working-tree changes**

Run: `git status --short`
Expected: only the intended new/modified files across Tasks 1–5; no stray edits.

- [ ] **Step 3: Manual hook-wiring check (cannot be automated — hooks load at session start)**

Because Claude Code loads hooks at session start, the live wiring is verified manually after
this branch is installed/loaded:
1. With the plugin enabled, restart Claude Code (or `claude --debug`).
2. Run `/hooks` and confirm a `PreToolUse` entry for `Write|Edit` pointing at
   `guard-docs-path.sh` is listed.
3. In a Magento project, attempt to write `src/.docs/scratch.md` → expect a block with the
   guard's stderr message; attempt `.docs/scratch.md` at the project root → expect success.

Record the outcome in the PR description (this step is operational verification, not a code
change).

---

## Self-review

**Spec coverage** (`.docs/context-docs-path-guard-hook-design.md`):
- §2 decisions (hard block, fail-open, Approach A, scope gate, Write/Edit) → Tasks 1–3.
- §3 matcher rule → Task 1 matcher + every matcher unit case.
- §4 components 1–4 → entry (Task 2), matcher (Task 1), registration (Task 3), test (Tasks 1–2).
- §5 test matrix → Task 1 matcher cases + Task 2 integration cases (incl. fail-open & scope-off).
- §8 verification unknowns → resolved (hooks.json wrapper format, exit-2 deny, env/stdin inputs)
  and exercised; live wiring → Task 6 Step 3.
- §9 versioning/docs → Task 5; CI/syntax coverage gap found during planning → Task 4.

**Placeholder scan:** none — every step has concrete code, exact paths, exact commands, and
expected output.

**Type/name consistency:** the function `docs_path_decide` is defined in Task 1 and called
identically in Task 2's entry script and both test blocks; file paths (`hooks/docs-path-matcher.sh`,
`hooks/guard-docs-path.sh`, `hooks/hooks.json`, `tests/test-docs-path-guard.sh`) are consistent
throughout.
