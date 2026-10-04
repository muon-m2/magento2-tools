# Core Rules — Full Text

Part of the `feature` skill — read at session start, and whenever a condensed Core Rule in SKILL.md needs its full text.

- **Mode-driven.** Pick a mode in Phase 1 (`feature`, `hotfix`, `extend`, `spike`).
  See `references/modes.md`. Default: `feature`. `hotfix` skips Phases 3-4 entirely;
  `extend` skips Phase 3 only and keeps a **minimal Phase 4** that still writes `plan.md`
  with a `## Current State` checklist — so every mode that executes tasks has a checklist
  to maintain and resume from.
- **Save before present.** Every review artifact (`blueprint.md` in Phase 2, `plan.md` in Phase 4)
  must be **written to disk and confirmed to exist** before it is presented to the user — never
  present one from memory. After writing, verify the file is on disk (e.g. read it back) and cite
  its path in the message. The user reviews the file, not just the chat. This applies to the
  detailed task records too (`tasks.md` / `tasks/`): they are written **before** the Phase 4
  approval gate, alongside `plan.md`, so the user can review the full task detail — not just the
  index — before approving. They are still kept **out** of `plan.md` itself (no duplication).
- **Continuous execution.** Once the Phase 4 plan gate is passed, Phases 5-7 run to completion in
  one uninterrupted stretch. **Do not pause to check in with the user between tasks** — "Should I
  continue?" prompts and progress summaries waste their time; the user approved the plan, so
  execute it. **Finishing a task is not a stopping point.** Completing a task, flipping its `[x]`
  in `plan.md`, and making its commit are the *cue to start the next task in the same turn* — not
  a hand-back. The same applies at phase boundaries: roll from the last Phase 5 task into Phase 6,
  and from 6 into 7, without asking. After the plan gate the **only** sanctioned stops are:
  (a) a blocking ambiguity no reasonable assumption can resolve (per **Ask once**);
  (b) an input the run cannot obtain itself — e.g. a smoke admin credential (`references/smoke-runner.md`);
  (c) the 5-iteration smoke cap in Phase 6B; and
  (d) Phase 7B delivered — the run is done.
  Anything else — "task X complete, ready for Y?", a mid-run status recap, waiting for "continue" —
  is a defect in the run, not politeness.
- **Test-first for behaviour (opt-in).** When TDD mode is on (`--tdd`, CLAUDE.md
  `Feature implement: tdd = on`, or `MAGENTO2_FI_TDD=1`), behaviour-bearing `M*`/`X*` tasks are
  implemented test-first (red → green → refactor): write the failing test, watch it fail for the
  right reason, then write the minimal code to pass. Pure scaffold/config stays generated-then-
  covered. Off by default; `spike` mode is always exempt. See `references/tdd-mode.md` and the
  shared loop in `context/references/tdd-discipline.md`.
- **Smoke before report.** Phase 6 has two sub-phases: **6A** (unit tests + coverage) and **6B**
  (smoke battery — REST scenarios, admin login, Stores → Config, grids, new routes, customer
  flows, error-signal diff). Phase 7 may not start while any Critical or High smoke finding is
  open. See `references/smoke-test-guide.md`.
- **Smoke tooling is policy, not preference.** REST and GraphQL scenarios always use `curl`;
  admin and storefront suites use a **headless** browser and never a headed one or a
  browser-automation MCP server. A missing browser is expected, not an error — S3–S7 degrade to a
  curl tier and emit a mandatory Medium coverage finding rather than being skipped. An explicit
  user directive ("do not use browser", "use curl") outranks every probe. The rules, the
  precedence order, and the trigger phrasings live in
  `context/references/runtime-test-tooling.md`.
- **Document before report (required).** Phase 7 is split into **7A** (documentation) and **7B**
  (final report). Phase 7B may not start until the feature's documentation set exists on disk and
  is current. Documentation is a required deliverable — not an optional extra — in `feature` and
  `extend` modes. The set spans three scopes (technical, developer, user), carries screenshots, and,
  when the feature exposes a REST/GraphQL surface, includes request/response payload examples. Per-
  module technical reference docs are delegated to `docs`. The required artifacts,
  per-mode scope, and the completeness gate live in `references/documentation-guide.md`.
- **Guides and user docs are HTML.** Development guides and user documentation default to `.html`
  format. Define a CSS color schema once for the feature and apply it inline to every HTML file
  in the feature folder for visual consistency. Every HTML file must declare
  `<meta charset="utf-8">` as the first element inside `<head>`, ahead of `<title>`: these are
  read over `file://`, where there is no HTTP `Content-Type` header, so an undeclared UTF-8 file
  is sniffed as windows-1252 and every em dash renders as `â€”`.
- **Per-task git commits (opt-in).** When `--per-task-commits` is set, CLAUDE.md contains
  `Feature implement: per-task commits = on`, or `MAGENTO2_FI_PER_TASK_COMMITS=1` is set,
  every completed task in Phase 5 produces a focused git commit. See
  `references/per-task-commits.md` for format, scoping rules, and failure handling. Off by default.
- **Model tiering.** Each Phase 4 task record carries a `Model tier (advisory)` field
  (`opus`/`sonnet`/`haiku`) recommending the tier that task would ideally run on — see
  `references/task-breakdown-guide.md` §"Model tier (advisory)". Sequential sub-skill tasks run
  through the `Skill` tool on the session model (no sub-skill of this plugin pins a `model:`), so
  for them the field guides manual `/model` switching. Tiers take live effect wherever this skill
  **dispatches a subagent**, because the `Agent` tool's `model` parameter pins it — follow
  `context/references/execution-modes.md` §"Subagent dispatch" on every dispatch: the plugin's
  `explorer` (default `haiku`, or the `CLAUDE.md` directive `Explorer model: {tier}`) for
  comprehension and blueprint/seam verification, `reviewer` for findings (`opus` for the Security
  and Architecture/API dimensions, `sonnet` otherwise), never the built-in `Explore` or
  `general-purpose` agents for that work, and an explicit `model` on every `Agent` call —
  including docs and smoke helpers (`sonnet`).
- **Delegate by probing, never by assumption.** The sub-skills of this pack ship in the **same
  plugin** as this skill — if this skill is running, the plugin is installed and they are
  Skill-invocable. Decide a sub-skill's availability by *attempting* its `Skill` invocation and
  falling back only on an actual failure (the tool reports no such skill). **Never** pre-declare a
  sub-skill — or the whole skill family — unreachable, and never skip delegation "from
  memory," from a project note, or on a blanket "not Skill-invocable here" assumption. A task that
  falls back to inline MUST record the concrete invocation failure that justified it; an
  unverifiable citation is not a reason. Inline is the exception for a genuinely absent skill, not
  the default — see the **Fallback discipline** note at the start of Phase 5.
- **Deploy delegation.** D* tasks delegate to `deploy`. The skill is invoked with the
  module list and the user's environment selection; `feature` does not run
  `bin/magento` commands itself — `deploy` owns the deploy plan (and the manual-next-steps
  fallback when it is absent).
