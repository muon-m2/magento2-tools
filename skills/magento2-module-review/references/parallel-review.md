# Parallel Review

Use parallel subagents only when the user explicitly authorizes delegation, parallel agents, or subagent work. Parallel
review is useful for large modules, security-sensitive modules, or modules with many independent surfaces. It is not
required for small modules.

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

Spawn subagents with the `Agent` tool. Prefer the plugin's first-party `subagent_type: 'magento2-reviewer'`
(a read-only Magento reviewer that loads this checklist + the shared severity scale, defined in
`agents/magento2-reviewer.md`) for the Security, Architecture, Frontend, Testing, and Performance
dimensions — dispatch one per subtask scope. Use `subagent_type: 'Explore'` for bounded evidence
collection / file inventory when you only need files located, not judged. If `magento2-reviewer` is
unavailable in the session, fall back to `subagent_type: 'claude'`. Pass the module path and subtask
scope in the prompt. Each subagent must receive a self-contained brief — it has no access to the
parent conversation.

## Model Guidance

In Claude Code, pass the `model` parameter on the `Agent` tool call to control per-subagent model selection:

- Pass `model: "opus"` for security and architecture subtasks (final synthesis, auth/ACL review, DI analysis).
- Pass `model: "haiku"` for bounded evidence collection, file inventories, and mechanical checklist passes.
- Do not ask subagents to edit files unless the user requested fixes and each subagent has a disjoint write scope.
- Do not duplicate the same review scope across multiple subagents unless independent confirmation is explicitly needed.
