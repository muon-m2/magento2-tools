# Process-Skill Deferral Policy (shared)

When a `magento2-*` orchestrator may defer to a generic, session-available process skill
(e.g. the `superpowers:*` family) — and, more often, when it must not. This is the single
source of truth; orchestrators point here instead of restating the policy or naming foreign
skills inline. Sits beside `tdd-discipline.md`, which already cites
`superpowers:test-driven-development` as its alignment anchor — the same pattern, generalized.

## Core principle

The orchestrators (`magento2-feature-implement`, `magento2-bug-fix`, `magento2-module-upgrade`)
already **own** their process surface — elicitation, planning, TDD, debugging, review, and
verification are each a domain-tuned phase with its own templates, gates, and references. A
generic process skill is therefore almost always **duplication, not augmentation**.

Three rules govern any deferral:

1. **Never a hard dependency.** A generic skill may be *absent*. Every phase MUST work
   standalone from its owned reference. Deferral is "prefer if present," never "require."
2. **Defer only at a hand-wave.** Defer only where the orchestrator names a *generic
   mechanism* it does not fully specify — never where it owns a domain-tuned discipline.
3. **No branching logic.** Do not probe "is X installed?" and fork. Name the capability,
   prefer it if the session already surfaced it, otherwise follow the owned reference. One
   sentence in the phase — no conditional plumbing.

## Defer-if-present (sanctioned)

| Mechanism the orchestrator hand-waves | Generic skill — prefer if present | Owned baseline — authority, stands alone |
|---|---|---|
| Safe parallel sub-agent dispatch (isolation, no shared state) | `superpowers:dispatching-parallel-agents` | `magento2-feature-implement/references/task-breakdown-guide.md` § Parallel Execution |

This is currently the **only** sanctioned deferral. The owned reference stays the authority on
*what* may run in parallel (its Magento rules: never review-with-its-creation, never two tasks
writing the same module); the generic skill only layers *how-to-dispatch-safely* mechanics on
top. If it is absent, the owned section is complete on its own.

## Do NOT defer — the orchestrator owns these

| Phase / surface | Owned by | Why not the generic skill |
|---|---|---|
| Requirement elicitation | FI Phase 1 (single-batch, "ask once") | `superpowers:brainstorming` is open-ended and iterative — it **conflicts** with the deliberate one-batch rule (FI Core Rules → "Ask once"). |
| Blueprint + task plan | FI Phases 2 & 4 (+ templates, gates) | `writing-plans` / `executing-plans` duplicate the owned templates, approval gates, and resumable `plan.md` Current State checklist. |
| Test-first discipline | `tdd-discipline.md` (shared) | Two TDD authorities drift. The owned loop is tuned to Magento class types (behaviour vs `db_schema`/DI/DTO). It **already** cites `superpowers:test-driven-development` as its anchor — that citation *is* the deferral; do not add a second. |
| Reproduce → root-cause → fix | BF Phases 1–3 | `systematic-debugging` is duplicated near-verbatim, plus Magento log-path and stack-trace specifics the generic skill lacks. |
| Code review | `magento2-module-review` | Domain-specific (ACL, output escaping, DI, Marketplace EQP). A generic review skill misses the Magento rule set. |
| Completion verification | FI Phase 6 (smoke + "tests must pass" + "read it back") | `verification-before-completion` is already internalized as owned rules — deferring would double the gate, not strengthen it. |

## Referencing a generic skill

Name it, don't link it: write `` `superpowers:dispatching-parallel-agents` `` inline — never an
`@`-path (force-loads context before it is needed) and never a bare "see the parallel skill"
(ambiguous about whether it is required). Always mark it optional ("if present" / "prefer if
available") so a session without it is a clean no-op, not a broken reference.
