# Parallel Review

Use parallel subagents only when `agents` mode is selected — by a `--agents` flag, plain
language ("use parallel agents", "delegate"), or `execution_mode` in `.claude/m2.json` (`{ctx.execution_mode}`)
(`context/references/execution-modes.md` is the selection contract). Parallel review is
useful for large modules, security-sensitive modules, or modules with many independent
surfaces. It is not required for small modules.

The main reviewer must own final synthesis:

- Deduplicate overlapping findings.
- Normalize severity across all subtask results.
- Verify file and line references.
- Resolve conflicting recommendations.
- Keep the final report coherent and findings-first.

### Tie-breaking contradictory findings

When two subagents reach contradictory conclusions about the same code location, apply these rules in order:

1. **Evidence wins over interpretation.** Favour the finding that cites a concrete `file:line` reference and quotes the
   specific code over the one that describes a general pattern without evidence. A claim with evidence always outranks
   one without.
2. **Higher severity requires stronger justification.** If one subagent rates a finding High and another rates the same
   finding Low, the higher severity stands only when the evidence directly shows a security or data-integrity impact (
   e.g., a missing ACL check on an admin route that accepts POST input is direct impact; a theoretical SQL injection
   risk where no user-controlled value reaches the query path is not). Downgrade otherwise and add a note explaining the
   disagreement.
3. **Security reviewer takes precedence on security items.** For findings that touch auth, ACL, CSRF, escaping, or
   secrets, the Security subtask result is authoritative. Other subtasks may flag the same item but must defer on
   severity.
4. **Flag unresolved conflicts explicitly.** When none of the above rules produces a clear winner, include both
   perspectives as a single **Medium** finding. Prefix the title with `[CONFLICT]`, document the disagreement
   between subagents, and recommend a manual verification step. Do not invent a severity level outside the
   taxonomy (Critical / High / Medium / Low / Info).

## Subtask Split

- **Architecture/API:** registration, Composer metadata, module dependencies, DI, service contracts, repositories,
  resource models, declarative schema, setup patches.
- **Security:** auth, ACL, CSRF, escaping, secrets, tokens, SQL/file/redirect risks, web APIs, GraphQL, public
  endpoints.
- **Frontend/admin:** layout XML, PHTML, blocks, view models, email templates, UI components, JS/CSS, admin
  `system.xml`.
- **Testing/tooling:** unit/integration/API/MFTF coverage, test quality, static-analysis results, Composer/package
  warnings.
- **Performance/operations:** collections, indexes, cron, queues, plugins, observers, cache identities, remote calls,
  data retention.

## Claude Code Agent Guidance

Spawn subagents with the `Agent` tool. Prefer the plugin's first-party `subagent_type: 'reviewer'`
(a read-only Magento reviewer that loads this checklist + the shared severity scale, defined in
`agents/reviewer.md`) for the Security, Architecture, Frontend, Testing, and Performance
dimensions — dispatch one per subtask scope. Use `subagent_type: 'Explore'` for bounded evidence
collection / file inventory when you only need files located, not judged. If `reviewer` is
unavailable in the session, fall back to `subagent_type: 'claude'`. Pass the module path and subtask
scope in the prompt. Each subagent must receive a self-contained brief — it has no access to the
parent conversation.

For the **inventory / comprehension step** (understanding the module's execution paths, extension
points, and cross-module dependencies before judging them), prefer
`subagent_type: 'explorer'` (defined in `agents/explorer.md`) — it produces a
structured comprehension map and Mermaid call-chain diagram. Fall back to `subagent_type: 'Explore'`
if `explorer` is unavailable, then to `subagent_type: 'claude'` — still passing `model: "haiku"`,
because a built-in agent dispatched without a `model` inherits the session model. Run the explorer step
first; pass its comprehension map to the per-dimension `reviewer` subagents so they start
with a shared understanding of the module's structure. The per-dimension judging still uses
`reviewer`. When dispatching `explorer`, pass `model` from the `CLAUDE.md`
directive `Explorer model: {tier}` if the project sets one; otherwise the agent's own default tier
(`haiku`) applies. This keeps the read-only comprehension pass cheap; the per-dimension `reviewer` judging is
tiered separately (Model Guidance below).

## Model Guidance

In Claude Code, pass the `model` parameter on **every** `Agent` tool call — it overrides the agent's
frontmatter default. `reviewer` defaults to `sonnet` (capped at 80 turns); `explorer` defaults to
`haiku` (capped at 50).

- Pass `model: "opus"` for the **Security** and **Architecture/API** dimensions (auth/ACL review,
  DI analysis) — these are never downgraded.
- Pass `model: "sonnet"` for the other review dimensions (Frontend/admin, Testing/tooling,
  Performance/operations).
- Pass `model: "haiku"` for bounded evidence collection, file inventories, and mechanical checklist passes.
- Final synthesis (dedup, severity normalization, tie-breaking) stays with this skill in the main
  conversation — it is never delegated.
- The read-only `explorer` inventory pass defaults to `haiku` (set in its agent
  frontmatter); override per project with the `CLAUDE.md` directive `Explorer model: {tier}`.
- Do not ask subagents to edit files unless the user requested fixes and each subagent has a disjoint write scope.
- Do not duplicate the same review scope across multiple subagents unless independent confirmation is explicitly needed.
