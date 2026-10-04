# Execution Modes (Shared)

How a findings/RCA skill decides whether its analysis runs as parallel **subagents** or
**inline** in the main conversation. Consumed by `audit`, `review`, `security`,
`perf-audit`, `a11y-audit`, `marketplace`, and `fix`. The mode changes only *where* the
work runs — the same references, checklists, and findings schema apply either way.

## The modes

| Mode | What happens | When it wins |
|------|--------------|--------------|
| `agents` | Read-only subagents are dispatched in parallel — `reviewer` (one per findings dimension), `explorer` (comprehension / RCA path-tracing) — and the skill owns synthesis: dedup, severity normalization, conflict tie-breaking. | Large modules, multi-dimension audits, security-sensitive targets. Faster wall-clock; main context stays small. |
| `inline` | The skill executes the same analysis itself, sequentially, in the main conversation. | Small targets, step-by-step steering, environments where subagents are unavailable. Token-frugal **only while the conversation is small**: every inline turn re-reads the whole main context, so in a conversation already holding hundreds of thousands of tokens the same analysis costs many times what it costs in a fresh subagent. |
| `auto` | Resolves per run to `agents` or `inline` — see **`auto` resolution** below. | The default for every consumer except `audit`: inline in a small conversation, fresh-context subagents once the conversation is already large. |

## Selection, in precedence order

1. **Per run** — `--agents` or `--inline` on the invocation, or plain language
   ("in one flow", "without subagents", "use parallel agents", "delegate").
2. **Per project** — `execution_mode` (`"agents"` | `"inline"` | `"auto"`) in `.claude/m2.json`,
   the plugin's own override file:

   ```json
   { "execution_mode": "agents" }
   ```

   Do **not** read this from Claude Code's `.claude/settings.json`. That file is not
   parsed by this plugin, and Claude Code accepts unknown keys there silently — a typo
   would fail without a single diagnostic. `m2.json` is resolved by
   `context/scripts/resolve-context.sh` alongside `magento_root` / `php_container`, so
   the value arrives as the context field `{ctx.execution_mode}` (with its origin in
   `{ctx.resolution_source.execution_mode}`). Read it from the context document you
   already resolved in Phase 0 — never re-read the file yourself.

   `null` means no project preference. A value that is not `agents`, `inline` or `auto`
   also resolves to `null`, with the reason recorded in `resolution_source` — an
   unrecognised mode is an honest gap, never a silently invented execution shape.
3. **Per-skill default** — `audit` defaults to `agents` (its whole point is the
   fan-out); every other consumer defaults to `auto`.

State the chosen mode (and what chose it: flag, `m2.json`, or default) in the run header
of the report. When `resolution_source.execution_mode` records an unresolved value, say
so there too rather than silently falling through to the default.

## `auto` resolution

`auto` resolves to **`agents`** when the plugin's context-budget hook
(`hooks/context-budget.sh`) reported the conversation above its threshold **for this
invocation** — a `magento2-tools context-budget: ctx_tokens=… status=above` note injected with
the `/magento2-tools:…` prompt, or alongside the `Skill` result when another skill chained into
this one. Otherwise it resolves to **`inline`**. Use only the note attached to the current
invocation, never one left over from an earlier run.

The threshold is `MAGENTO2_TOOLS_CTX_WARN` (default `200000` tokens; `0` disables the hook, so
`auto` always resolves to `inline`). Record the resolution in the run header, e.g.
`Mode: agents (auto — context ~727k > 200k)` or `Mode: inline (auto — no context-budget note)`.

## Subagent dispatch

- **Plugin agents for Magento analysis.** Dispatch `reviewer` for findings and `explorer` for
  comprehension / RCA path-tracing / blueprint verification. The built-in `Explore`,
  `general-purpose` and `claude` agents are a fallback only when a plugin agent is unavailable.
- **Pass `model` on every `Agent` call.** It overrides the agent's frontmatter default, and a
  built-in agent dispatched without one inherits the session model. Tiers: `reviewer` → `opus`
  for the Security and Architecture/API dimensions, `sonnet` (its default) otherwise; `explorer`
  → the `CLAUDE.md` directive `Explorer model: {tier}` if set, else `haiku`; any helper agent
  (docs drafting, smoke running) → `sonnet` unless the task needs more.
- **Turn caps.** `reviewer` stops at 80 turns and `explorer` at 50 (`maxTurns`). A capped agent
  returns partial output marked as such — report the coverage gap instead of silently
  re-dispatching the same scope.

## Invariants — identical in both modes

- **Approval gates always run in the main conversation.** A gate (RCA approval, deploy
  confirmation, fix authorization) is never delegated to a subagent, in either mode.
- **Same canon.** Both modes read the same reference packs and emit the same
  findings-schema JSON/SARIF via the shared emitters. Scripted scanners
  (`build-findings.sh`) are deterministic and run as scripts in both modes.
- **Read-only agents.** `reviewer` and `explorer` never modify code; only the main
  conversation writes.

## Documented divergence

An inline run can pause and ask the user a clarifying question mid-analysis. A subagent
cannot: in `agents` mode, ambiguities are resolved conservatively and listed in the
report under **Open questions** instead. This difference is inherent, not a bug — pick
`inline` when the target is ambiguous enough that mid-run steering matters.
