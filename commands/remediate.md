---
description: Execute an approved remediation plan batch by batch through the owning skills — one approval per batch, one commit per finding (remediate)
argument-hint: "[<Vendor>_<Module>] [--from=<plan.json|audit.json>] [--batch=<owner,…>] [--dry-run] [--yes-auto] [--no-closure] [--docs-root=<path>]"
disable-model-invocation: true
---
Use the `magento2-tools:remediate` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not collapse the per-batch approval gate, execute a `gate: manual` finding, or skip the
closure diff unless `--no-closure` was passed. The skill's batch gate and its
never-count-an-unverified-batch-clean rule apply unchanged.
