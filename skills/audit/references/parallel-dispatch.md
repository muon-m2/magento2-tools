# Parallel Dispatch

How `audit` fans the dimensions out, and the model tiers it applies.

## Authorization

Dispatching several read-only subagents at once is opt-in, exactly like
`review`'s parallel review. Ask once before Phase 2 unless the user already
requested parallel/fast execution. If declined, run the dimensions **sequentially** — the Phase 3
consolidation is byte-for-byte identical either way, only slower.

## What runs as an agent vs a script

- **`reviewer` subagents** — one per review dimension (Architecture/API, Security,
  Frontend/admin, Testing/tooling, Performance/operations). Each gets a self-contained brief (module
  path + dimension scope) per `review/references/parallel-review.md`, and returns a
  findings-schema JSON document. Launch them in a single batch so they run concurrently.
- **Scripted scanners** — the specialist `build-findings.sh` scripts run directly via Bash and can
  be backgrounded; they do not consume an agent slot.

## Model tiers

Pin each subagent's tier with the `Agent` tool's `model` parameter, on **every** dispatch — it
overrides the agent's frontmatter default (`reviewer` defaults to `sonnet`), and a dispatch with
no `model` silently runs on whatever the agent or session default happens to be. Apply the tiers
from `dimensions.md`:

- **opus** — the Security and Architecture/API review dimensions: they weigh cross-cutting
  evidence (auth/ACL, DI wiring) and are never downgraded.
- **sonnet** — the Performance/operations review dimension.
- **haiku** — the scripted scanners' wrapper turns and the mechanical review dimensions
  (Frontend/admin, Testing/tooling): cheap, high-recall, low-judgement.

The Phase 3 consolidation judgement runs in the main conversation on the session model. If the
harness cannot pin a subagent's model, dispatch on the session model and note it.

## Failure isolation

A dimension that errors (agent dies, scanner returns non-zero) must not abort the audit. Capture its
failure, exclude its (absent) document from consolidation, and surface it in the report's coverage
table as **errored** — distinct from **skipped** (not applicable) and **clean** (ran, no findings).
