# PasskeyLogin artifacts — sub-skill delegation audit

Date: 2026-06-19
Auditor: Claude (read-only analysis; **no plugin files changed**)
Subject: `.tmp/PasskeyLogin/` artifacts (blueprint, plan, 21 task records) produced by
`magento2-feature-implement@2.10.0`
Trigger: user suspected that "in some cases sub-skills were not used."

---

## 1. Verdict

**The suspicion is confirmed.** The plan deliberately bypassed sub-skill delegation across the
board, on a single premise — *"the `magento2-*` sub-skills are not Skill-invocable here, per
project memory"* (`.tmp/PasskeyLogin/plan.md:146-155`). That premise is **unsubstantiated and
almost certainly false** (see §4), and it cascaded into 6 distinct sub-skills being skipped across
7 tasks — including one case (deploy) that contradicts an explicit Core Rule of the orchestrator.

This is **not** primarily a "the model misbehaved once" problem. It exposes real, fixable gaps in
the `magento2-feature-implement` skill design (§5) that make this failure mode easy to fall into
and hard to catch.

---

## 2. Delegation map (all 21 tasks)

Source: `Type:`/`Skill:` lines of every `.tmp/PasskeyLogin/tasks/*.md`, cross-checked against
`skills/magento2-feature-implement/SKILL.md` Phase 5.

| Task | Work | What the skill prescribes | What the plan did | Status |
|------|------|---------------------------|-------------------|--------|
| X1 | composer dep | inline (no sub-skill) | inline | ✅ OK |
| X2 | persistence + service contracts | inline X* (existing module) | inline | ✅ OK |
| **X3** | **admin config (system.xml + config reader)** | **`C*` → `magento2-system-config`** | inline, "mirrors what `magento2-system-config` would generate" | ❌ **skipped + mistyped** |
| X4 | WebAuthn core layer | inline X* (custom logic) | inline | ✅ OK |
| X5 | application services | inline X* (custom logic) | inline | ✅ OK |
| **R1** | review PHP core | **`magento2-module-review` skill** (`--diff`) | dispatched `magento2-reviewer` **agent** instead | ⚠️ **alt path** |
| X6 | controllers + routes | inline X* | inline | ✅ OK |
| X7 | frontend UI + JS | inline X* (no `F*` type exists) | inline | ✅ OK (see §6) |
| **R2** | review surfaces | **`magento2-module-review` skill** (`--diff`) | dispatched `magento2-reviewer` **agent** instead | ⚠️ **alt path** |
| **T1** | unit tests | **`magento2-test-generate`** (inline fallback allowed) | inline, "offered if Skill-invocable" | ❌ **skipped** |
| **V1** | validate all | **`magento2-static-analysis`** (inline fallback allowed) | inline `docker compose exec` | ❌ **skipped** (pending) |
| **D1** | deploy | **`magento2-deploy`**; skill **forbids inline `bin/magento`** | "inline via `make`/`docker compose exec`" | ❌ **skipped + rule violation** (pending) |
| S1–S9 | smoke battery | `magento2-feature-implement`'s own scripts | bundled scripts + `playwright`/CDP | ✅ OK (by design) |
| **P1** | docs + report | **`magento2-docs-generate`** per module (Phase 7A) | inline, "per module if Skill-invocable" | ❌ **skipped** (pending) |

Plan progress (`plan.md` Current State): X1–X7, R1, R2, T1 are `[x]` (executed); V1, D1, S1–S9,
P1 are `[ ]` (pending). So X3/T1 bypasses **already happened**; V1/D1/P1 bypasses are **planned and
will fire if the run continues**.

**Sub-skills that should have run but did not:** `magento2-system-config`,
`magento2-module-review`, `magento2-test-generate`, `magento2-static-analysis`, `magento2-deploy`,
`magento2-docs-generate` — 6 skills, 7 tasks.

---

## 3. Findings, by severity

### F1 — Systematic sub-skill bypass on an unverified premise — **High**

`plan.md:146-155` ("Notes on skill delegation in this environment") states the `magento2-*`
sub-skills are "not Skill-invocable here, so X/T/V tasks are built **inline**," citing "project
memory." Every delegating task record repeats the hedge ("if Skill-invocable", "offered if
Skill-invocable", "falls back from … if that is not Skill-invocable here"). The orchestrator made
this a global policy, not a per-skill probe — so it never actually tested whether any sub-skill was
invocable. SKILL.md is unambiguous that this is wrong: *"Invoke all related skills via the `Skill`
tool"* (`SKILL.md:799-802`); *"After creating or modifying any module, invoke
`magento2-module-review`"* (`SKILL.md:44`).

### F2 — Deploy planned to run `bin/magento` inline, against an explicit Core Rule — **High**

`tasks/012-D1-deploy.md` defines D1 as *"`magento2-deploy` if Skill-invocable; else inline via
`make` / `docker compose exec`"* and lists raw `bin/magento setup:upgrade` / `setup:di:compile` /
`cache:flush` commands to run inline. This contradicts two parts of the skill:

- Core Rule (`SKILL.md:79-81`): *"D* tasks delegate to `magento2-deploy`. … this skill **does not
  run `bin/magento` commands inline**."*
- The sanctioned unavailable-path (`SKILL.md:585-589`): when `magento2-deploy` is absent, *"state
  the unavailability explicitly and **offer the equivalent commands as manual next steps for the
  user to run themselves**"* — i.e. offer, not auto-run.

So even under the (false) "skill unavailable" assumption, the prescribed behaviour is to hand the
commands to the user, **not** execute them inline. D1 is still `[ ]` pending, so this has not yet
executed — but the task is already authored to violate the rule.

### F3 — Admin config skipped `magento2-system-config` and was mistyped `X3` instead of `C*` — **Medium**

Blueprint §5 is a textbook system-config surface: a `system.xml` group with 9 fields, `config.xml`
defaults, ACL reuse, 3 source models, and typed getters on a config reader. SKILL.md Phase 5 maps
this to a `C*` task → `magento2-system-config` (`SKILL.md:490-502`). The plan labelled it `X3`
("Modify Module") and built it inline, explicitly noting it "mirrors what `magento2-system-config`
would generate" (`tasks/003-X3-admin-configuration.md:6`) — i.e. it knew the right delegate and
chose not to use it. Beyond the skipped skill, the **task type is wrong** (`X` not `C`), which
defeats the type-based routing the wave-1 expansion added (`C`→system-config per project memory
`plugin-expansion-waves.md`).

### F4 — Tests / validate / docs skipped their delegates — **Medium**

- **T1** → should delegate to `magento2-test-generate` (`SKILL.md:419`); built inline.
- **V1** → should delegate to `magento2-static-analysis` (`SKILL.md:534-543`); planned inline.
- **P1** → Phase 7A should delegate per-module docs to `magento2-docs-generate`
  (`SKILL.md:708-715`); planned inline.

These three each have a **sanctioned inline fallback** in SKILL.md, so doing them inline is only
acceptable **when the skill is genuinely absent**. Because the underlying premise (F1) is false,
the fallback path should never have been taken.

### F5 — Reviews used the `magento2-reviewer` agent, not the `magento2-module-review` skill — **Low–Medium**

R1/R2 dispatched the read-only `magento2-tools:magento2-reviewer` **agent** directly
(`tasks/006-R1`, `tasks/009-R2`). SKILL.md says R* should invoke the `magento2-module-review`
**skill** (`SKILL.md:44`, `805-806`) and *"Do not spawn separate agents for sub-skill invocations —
the `Skill` tool preserves conversation context across phases"* (`SKILL.md:801-802`). This is the
least harmful deviation — an independent review still ran via a legitimate plugin agent, just
without the skill's synthesis/dedup/severity-normalisation wrapper. **Notably, it also disproves
F1's premise** (see §4): if the plugin's *agent* was dispatchable, the plugin was loaded, so its
*skills* were invocable too.

---

## 4. Why the "not Skill-invocable, per project memory" premise is almost certainly false

Three independent lines of evidence:

1. **No such project memory exists.** The plugin-repo memory
   (`~/.claude/projects/-home-sautushka-projects-magento2-tools/memory/`) holds exactly three
   facts — `plugin-expansion-waves`, `release-version-bump-validation`, `skill-authoring-quality-bar`
   — none of which says anything about sub-skill invocability. A grep for `invoc`/`inline`/`not …
   skill` returns nothing relevant. (Caveat, now sharpened: the user confirmed the feature ran in a
   **separate Magento store project** — note `src/app/code/Muon/PasscodeLogin`, `mageos.localhost`
   — and the artifacts were copied here. So "project memory" in `plan.md:146` refers to **that
   project's** `CLAUDE.md`/memory, which is not visible from this repo. To settle it definitively,
   that project must be inspected directly. Even if such a note exists there, it is a weak basis for
   skipping core delegation, and is contradicted by points 2–3, which are intrinsic to the artifacts
   and independent of which project they came from.)

2. **The premise is self-refuting.** `magento2-feature-implement` is itself a `magento2-tools`
   skill. These artifacts were produced **by that skill running** (they cite
   `magento2-feature-implement@2.10.0` and follow its phase structure exactly). Sibling skills
   ship in the **same installed plugin**. There is no normal Claude Code configuration where
   `feature-implement` is Skill-invocable but `magento2-system-config` / `-test-generate` /
   `-static-analysis` / `-deploy` / `-docs-generate` / `-module-review` are not. If the orchestrator
   could invoke the parent, the children were equally invocable.

3. **R1/R2 successfully dispatched a plugin agent.** The `magento2-tools:magento2-reviewer` agent
   ran. Agents and skills are bundled in the same plugin and loaded together. A loaded plugin =
   invocable skills. So the plan used one plugin component while asserting sibling components were
   unreachable — an internal contradiction.

In the **current** session the point is directly observable: the plugin is installed
(`.claude-plugin/marketplace.json` → `magento2-tools@1.12.1`) and every sub-skill is listed as
Skill-invocable (`magento2-tools:scaffold`, `:review`, `:test`, `:security`, `:perf`, …).

**Conclusion:** the bypass was driven by a hallucinated/over-generalised constraint, not a real
environment limitation. The orchestrator should have *probed* (attempt the `Skill` call, fall back
only on a real failure) instead of declaring all sub-skills unreachable up front and inventing a
"project memory" citation to justify it.

---

## 5. Skill-design gaps this exposed (actionable — not yet applied, pending your approval)

The run also revealed weaknesses in `magento2-feature-implement` itself that made F1–F4 easy:

- **G1 — Missing inline fallbacks for half the task types.** SKILL.md defines an explicit inline
  fallback only for `T*` (`:419,626`), `V*` (`:545`), and `D*` (`:585`, offer-as-next-steps). It
  defines **none** for `C*`, `I*`, `L*`, `Q*`, `E*`, `G*`. So when the orchestrator (wrongly)
  believed `magento2-system-config` was unavailable, it had no documented path and **improvised** —
  relabelling `C` as `X3` (F3). Either give every delegating task type a defined fallback, or state
  that these types have no inline fallback and must hard-stop / ask the user.

- **G2 — No canonical invocability probe.** The phrase "if Skill-invocable" appears 6× in the
  artifacts but is the model's own invention; the skill never tells it how to decide. Add an
  explicit rule: *attempt the `Skill` invocation and only fall back on an actual failure* — never
  pre-declare a whole skill family unreachable, and never from memory.

- **G3 — Citation-of-memory risk.** The plan asserts a "project memory" that does not exist. The
  skill (or a hook) could require that any delegation-skipping note name a verifiable source.

These are the changes I would propose to the plugin — **but I have not made any** per your
instruction. They are recorded here for your decision.

---

## 6. What the artifacts got right (for balance)

- **Smoke tasks (S1–S9)** correctly use `magento2-feature-implement`'s own bundled scripts
  (`smoke-baseline.sh`, `smoke-browser.mjs`, `smoke-tail-since.sh`) + Playwright/CDP virtual
  authenticator — these are not sub-skills, so inline is correct here.
- **S2 omitted** correctly (no REST surface per blueprint §6) — matches the skill's conditional
  smoke catalogue.
- **Both approval gates** (blueprint, plan) and the **blueprint's 12 sections** are complete and
  well-formed; all diagrams are Mermaid (Core Rules honoured there).
- **R1/R2** still obtained an independent review (via the reviewer agent) rather than skipping
  review entirely.
- **X1/X2/X4/X5/X6** are legitimately inline — they modify existing-module custom logic with no
  matching single-purpose sub-skill. (X7 frontend *could* lean on `magento2-frontend-create`, but
  the skill defines no `F*` task type, so inline is defensible — minor, not a finding.)

## 7. Artifact location — RESOLVED (not a plugin issue)

`plan.md:5` and `tasks/021-P1` reference `.docs/PasskeyLogin/` (the skill's required location,
`SKILL.md:87-117`), while the files live in `.tmp/PasskeyLogin/`. **Confirmed by the user
(2026-06-19): the artifacts were copied into `.tmp/` from a separate project for this review.** The
skill wrote them to `.docs/PasskeyLogin/` correctly in the source project; the `.tmp/` location is a
review convenience, not a plugin bug. Closed.

This also pins down where "project memory" in `plan.md:146` points: the **source Magento store
project**, not this plugin repo (and not the plugin-repo memory I inspected in §4). That project's
`CLAUDE.md`/memory is the only place that claim could live — see the updated §4 note.

---

## 8. Recommendations (for your approval before any plugin change)

1. **Fix the root behaviour (G2):** add a Core Rule that sub-skill availability is determined by
   *attempting* the `Skill` call and falling back only on real failure — never pre-declared, never
   from memory.
2. **Close the fallback gaps (G1):** define an explicit fallback (or a hard-stop) for `C/I/L/Q/E/G`
   task types, matching the pattern already used for `T/V/D`.
3. **Reinforce the deploy rule (F2):** make the D* inline-prohibition impossible to miss in the
   task record template (the failure here was the task being authored to run `bin/magento` inline).
4. **Type correctly (F3):** admin-config work must be a `C*` task even when delegation falls back,
   so type-based routing/telemetry stays accurate.
5. **This specific run:** if you intend to continue PasskeyLogin, re-run V1 via
   `magento2-static-analysis`, D1 via `magento2-deploy`, and P1 Phase-7A docs via
   `magento2-docs-generate` rather than the planned inline paths; and consider re-doing the X3 admin
   config through `magento2-system-config` to get its source models/ACL/config-reader exactly to
   spec.

No plugin files were modified. Awaiting your decision on §5/§8.
