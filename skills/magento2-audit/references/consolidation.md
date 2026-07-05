# Consolidation

How `scripts/consolidate.sh` collapses the per-dimension findings documents into one `audit`
document. This reference is the contract; the script is the implementation.

## Dedup key

Two findings are the same issue when all of these match:

- first evidence `file`
- first evidence `line`
- `category`
- normalized `title` (trimmed, lower-cased)

On a collision the merged finding keeps the **highest severity** of the duplicates and records every
dimension that raised it in a `dimensions` array (e.g. an ACL gap found by both the scripted
security scan and the reviewer's Security dimension appears once, tagged with both). This is why the
same defect surfacing in two dimensions never double-counts.

## Severity

Severities are the shared five-point scale (`magento2-context/references/severity.md`). Findings are
emitted severity-ranked, Critical first. No re-calibration across dimensions — a dimension's severity
is trusted as-is; only the dedup collision rule (keep-highest) changes a finding's severity.

## Verdict and score

Computed from the **deduped** findings:

- `audit_score` starts at 100 and subtracts a per-severity weight
  (critical 25, high 15, medium 5, low 1, info 0), floored at 0.
- `audit_verdict` = `FAIL` if any Critical or High remains, else `PASS` when score ≥ 85, else
  `CONDITIONAL`.

These plus `dimension_coverage` (one entry per dimension: name, outputKind, finding count, source
file) are injected into the JSON by the `audit-verdict.sh` POST_JSON_HOOK, so they land in the JSON
document but not the SARIF (SARIF carries only the findings).

## Output

The consolidated document is `outputKind=audit`, `skill=magento2-audit`, written to
`{output_root}/audits/{Vendor}_{Module}-audit-{date}.{json,sarif}` via the shared
`magento2-context/scripts/emit-findings.sh` — the same emitter every findings skill uses, so the
consolidated SARIF is valid for CI / GitHub Code Scanning like any single-dimension report.
