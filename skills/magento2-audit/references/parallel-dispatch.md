# Parallel Dispatch

How `magento2-audit` fans the dimensions out, and the model tiers it applies.

## Authorization

Dispatching several read-only subagents at once is opt-in, exactly like
`magento2-module-review`'s parallel review. Ask once before Phase 2 unless the user already
requested parallel/fast execution. If declined, run the dimensions **sequentially** — the Phase 3
consolidation is byte-for-byte identical either way, only slower.

## What runs as an agent vs a script

- **`magento2-reviewer` subagents** — one per review dimension (Architecture/API, Security,
  Frontend/admin, Testing/tooling, Performance/operations). Each gets a self-contained brief (module
  path + dimension scope) per `magento2-module-review/references/parallel-review.md`, and returns a
  findings-schema JSON document. Launch them in a single batch so they run concurrently.
- **Scripted scanners** — the specialist `build-findings.sh` scripts run directly via Bash and can
  be backgrounded; they do not consume an agent slot.

## Model tiers (advisory)

Tiers matter here because — unlike a sequential Skill-tool flow, which always runs on the session
model — **subagent dispatch can pin a tier**. Apply the tiers from `dimensions.md`:

- **haiku** — the scripted scanners' wrapper turns and the mechanical review dimensions
  (Frontend/admin, Testing/tooling): cheap, high-recall, low-judgement.
- **session / opus** — Security and Performance/operations review, and the Phase 3 consolidation
  judgement: these weigh cross-cutting evidence and must not be downgraded.

`magento2-reviewer` is never downgraded below the session model for the Security dimension. Tiers are
advisory: if the harness cannot pin a subagent's model, dispatch on the session model and note it.

## Failure isolation

A dimension that errors (agent dies, scanner returns non-zero) must not abort the audit. Capture its
failure, exclude its (absent) document from consolidation, and surface it in the report's coverage
table as **errored** — distinct from **skipped** (not applicable) and **clean** (ran, no findings).
