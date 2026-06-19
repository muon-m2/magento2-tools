# Readiness Scoring

How `magento2-marketplace-prep` converts findings into a readiness score and a
PASS/FAIL/CONDITIONAL verdict.

## Tiering

Each finding has a **tier** that maps directly to the shared severity scale
(`magento2-context/references/severity.md`):

| EQP Tier | Shared Severity | Meaning |
|----------|-----------------|---------|
| blocker | `critical` / `high` | Blocks EQP approval; must-fix |
| warning | `medium` | Strongly recommended; may cause rejection or low score |
| info | `low` / `info` | Best practice; no immediate rejection risk |

### Blocker vs. Critical vs. High

Within the `blocker` tier, use the shared severity to distinguish impact:

- `critical` — blocks submission outright (e.g. no LICENSE file, no `registration.php`,
  `*` wildcard version constraint).
- `high` — very likely to block approval but may survive initial submission with an
  explanation (e.g. no MFTF tests when the extension type normally requires them).

For the verdict calculation, **any** `critical` or `high` finding counts as a blocker.

## Per-Check Severity Mapping

| Check (from eqp-checklist.md) | Severity | Rationale |
|-------------------------------|----------|-----------|
| composer.json missing | critical | Package cannot be built |
| name non-conforming | critical | EQP auto-rejects |
| type != magento2-module | critical | Wrong extension category |
| version missing | critical | Marketplace cannot list the package |
| license missing from composer.json | high | EQP will reject |
| magento/framework absent from require | high | Extension uninstallable |
| PHP constraint absent | high | Compatibility unknown |
| PSR-4 autoload absent | high | Classes unloadable |
| dev-*/wildcard constraints | critical | Marketplace rejects non-stable deps |
| LICENSE file missing | critical | Marketplace requires license file |
| registration.php missing | critical | Module cannot register |
| etc/module.xml missing | critical | Module declaration missing |
| Name mismatch (registration/module.xml) | critical | Install failure |
| Copyright header absent | medium | Coding standard; flagged in review |
| MFTF tests absent | medium | Quality score penalty |
| README absent | medium | Listing quality penalty |
| Dev artifacts committed | medium | Package hygiene |
| .gitignore absent | low | Minor hygiene gap |
| description absent | medium | Listing quality |
| authors absent | medium | Attribution requirement |
| archive.exclude not configured | low | Oversized package |
| CHANGELOG absent | low | Versioning transparency |
| Unit/integration tests absent | info | Quality score improvement |

## Score Formula

The readiness score is a weighted deduction from 100:

```
score = 100
      − (critical_count × 25)
      − (high_count    × 15)
      − (medium_count  ×  5)
      − (low_count     ×  1)

score = max(score, 0)
```

The score is reported as an integer 0–100 in the JSON document under `readiness_score`.

### Verdict

| Condition | Verdict | Meaning |
|-----------|---------|---------|
| score ≥ 85 AND 0 blockers | **PASS** | Ready to submit |
| score ≥ 70 AND 0 blockers | **CONDITIONAL** | Submittable; warnings should still be fixed |
| 0 blockers AND score < 70 | **CONDITIONAL** | Warning-heavy; address before submitting |
| Any blocker (critical or high) | **FAIL** | Cannot submit; fix blockers first |

## Interpreting the Report

1. **Blockers come first.** The Markdown report lists critical/high findings at the top.
2. **Fix blockers before looking at warnings.** Fixing a blocker often resolves related
   warnings automatically.
3. **Re-run after each fix cycle.** The score will update with each run.
4. **EQP static score is separate.** The EQP coding-standard findings (from
   `magento2-security-audit`) contribute to the combined JSON findings list but are
   shown in their own section in the Markdown report.

## JSON Fields

The emitted JSON document (via `build-findings.sh`) carries two extra top-level fields:

```json
{
  "readiness_score": 72,
  "readiness_verdict": "CONDITIONAL",
  ...
}
```

These are injected by `build-findings.sh` after the standard emit-json.sh run.
