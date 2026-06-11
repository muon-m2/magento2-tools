# Smoke Test Guide (Phase 6B)

Phase 6B is the **smoke battery**: a fast, broad, behaviour-level check that the just-implemented
feature works *in a running Magento instance* and that nothing else regressed in the surfaces a
typical site cares about. It runs after Phase 6A (unit tests + coverage) and before Phase 7 (final
report).

Phase 6B is **mandatory** for `feature` mode. It is reduced in `hotfix` / `extend` modes and
skipped in `spike` mode (see `modes.md`).

---

## Suites

Phase 6B is composed of fixed suites with stable IDs. The skill emits one `S*` task per suite
applicable to the feature. Suites `S1` and `S8` are always present; `S2`–`S7` are emitted only
when the feature actually exercises that surface.

| ID | Suite | Always run? | Purpose |
|----|-------|-------------|---------|
| S1 | Baseline & probe | Yes | Snapshot `var/log/exception.log` byte offset; probe BASE_URL, admin URL, browser tool, credentials. Halts cleanly if a precondition is missing. |
| S2 | REST API scenarios | If feature adds/changes REST | Document and execute every scenario per endpoint (happy / missing-auth / wrong-ACL / validation / not-found / pagination). |
| S3 | Admin login | If admin surfaces touched (default: yes) | Browser opens `/admin`, posts credentials, asserts dashboard rendered, no JS console error. |
| S4 | Stores → Configuration | If feature adds/changes admin config | Walk every new/changed section; assert it renders with no exception. (Changing + reverting a field is best-effort: a headless write needs the form key + secret key, so do it manually or via a data fixture and note it.) |
| S5 | Admin grids | Always when admin surfaces touched | Customers, Catalog → Products, Sales → Orders. For each: load, assert rows render, apply one filter (clearing it is best-effort). Plus any new grid the feature added. |
| S6 | New / changed pages & controllers | Per route registered | One pass per admin and frontend route the feature owns. Render, screenshot, click primary CTA, assert no console error. |
| S7 | Customer storefront flows | If feature touches customer area or default flows | Register throwaway customer → log out → log back in → visit every My Account tab. Assert no console error and no exception. |
| S8 | Exception.log diff | Yes | Tail `var/log/exception.log` from S1 offset; fail if any new line appeared during S2–S7. |
| S9 | Triage & report | Yes | Classify findings, write `run-{N}.md`, decide pass/fail, drive loop. |

---

## Severity Rubric

Mirror `magento2-module-review`'s scale to keep reports composable.

| Severity | Definition (smoke) | Examples |
|----------|--------------------|----------|
| Critical | Site-down, data loss, security bypass, exception.log entry from new code path, admin or storefront 5xx | Admin login 500, REST endpoint dumps stack trace, registration creates customer with empty hash, schema rollback failed |
| High     | Broken golden path | Customers grid filter returns 0 rows when it should not, new REST 200s but ignores ACL, JS error blocks Save Config, page renders but missing the new section |
| Medium   | Visual regression, slow response > target, deprecation warning, non-blocking console error | New page renders > 2s, deprecation warning in `var/log/system.log`, console `error:` from unrelated 3rd-party JS |
| Low      | Copy/typo, cosmetic, suggestion | Label not translated, icon misaligned, redundant network request |

Only **Critical** and **High** trigger the auto-fix loop. Medium and Low are recorded but do not
gate the report.

---

## Fix Routing

When S9 records Critical/High findings, the skill delegates each one to the right sub-skill. The
mapping is deterministic — do not pick the skill ad-hoc.

| Finding category | Delegated to | Notes |
|------------------|--------------|-------|
| PHP exception in `var/log/exception.log` | `magento2-debug` (triage) → `magento2-bug-fix` | Pass run report path so debug skill has the reproduction. |
| Broken controller / route / layout | `magento2-bug-fix` | Re-runs `magento2-module-review --diff` after the fix. |
| Broken REST contract or response shape | `magento2-bug-fix` (+ `magento2-module-review --diff`) | Update scenarios.md if the contract was wrong, not the implementation. |
| Slow page / N+1 / cache miss | `magento2-performance-audit` → `magento2-bug-fix` | Performance audit produces the diagnosis; bug-fix applies the change. |
| Frontend (JS console, missing asset, KO bind error) | `magento2-frontend-create` → `magento2-bug-fix` | Add to the existing theme; do not scaffold a new module. |
| Security regression (ACL bypass, CSRF, escaping) | `magento2-security-audit` → `magento2-bug-fix` | Always re-run S2 fully after the fix. |
| Schema / patch issue | `magento2-data-migration` or direct edit | Direct edit only for trivial cases; data-migration for anything reseed-y. |
| Anything else | `magento2-bug-fix` | Default. |

After each fix, **re-deploy** via `magento2-deploy` if any PHP, XML, JS, or template file changed,
then re-enter Phase 6 from 6A.

---

## Loop Control

`plan.md` carries a smoke-iteration counter the skill maintains directly:

```
## Smoke Iterations
Count: 2 / 5
Last run: .docs/{FeatureName}/smoke/run-2.md
Outcome: 1 High remaining → re-entering Phase 6
```

Rules:

1. Increment **before** each Phase 6 entry (so the first smoke run is Count: 1 / 5).
2. After each S9, write the iteration's outcome to this block.
3. If the new count would exceed 5, **halt** before re-entering Phase 6. Print the halt prompt
   verbatim (see "Halt Prompt" below) and wait for an explicit user reply. Do not loop again.

### Halt Prompt

Print verbatim when iteration cap is reached with unresolved Critical/High:

> **Smoke iteration cap reached (5/5).**
> Unresolved findings: {N Critical, M High}
> See `.docs/{FeatureName}/smoke/findings.md` for the consolidated list and per-iteration history.
>
> Reply with one of:
> - **`retry`** — run Phase 6 once more (cap raised by 1 only).
> - **`accept-known-issues <ID1,ID2,...>`** — accept the listed finding IDs as documented limitations
>   and proceed to Phase 7. Listed IDs are downgraded to Known Limitations in the final report.
> - **`abort`** — stop and leave `plan.md` Status as `In Progress` for later resume.

If the user replies `accept-known-issues` without listing IDs, ask once for the list — do not
silently accept all.

---

## Pass Criteria for Phase 6B

Phase 6B passes when, simultaneously:

1. Every applicable suite (S1 + S2–S7 as relevant + S8 + S9) has run to completion.
2. S9 records zero Critical and zero High findings.
3. S8's exception.log diff has no **new or unresolved** exception groups (groups already
   marked `resolved` in findings.md may linger in the diff — see `exception-log-baseline.md`).
   An empty diff trivially satisfies this.

Any other outcome triggers the fix loop unless the cap is reached.

---

## Data Hygiene

Smoke runs must never leave persistent test data behind:

- Customer emails: `smoke+{uuid}@example.test` — created in S7. The S9 `cleanup` command
  navigates to the filtered customer grid but does NOT delete (a headless grid mass-delete
  needs the form + secret key); delete the throwaway customer manually or via a data fixture.
- Product / category / order SKUs (if created): prefixed `SMOKE-{uuid}-`.
- Admin config changes in S4: only make one if you can revert it — capture the original value
  first. The browser driver does not auto-revert; treat config mutation as manual/best-effort.
- Never run smoke against a base URL that resolves to production unless `CLAUDE.md` contains
  `Allow smoke on production: true`. Production base URL is identified heuristically: `.com`,
  `.io`, `.net` TLD with no `:port` and no `localhost`/`127.0.0.1`/`*.test`/`*.local` host.

---

## Output

Every Phase 6B run produces:

```
.docs/{FeatureName}/smoke/
├── baseline.txt           # S1 — exception.log byte offset + last-line digest
├── scenarios.md           # S2 — REST scenarios (rewritten each run; passing rows marked)
├── findings.md            # S9 — consolidated, severity-ranked, cross-iteration history
├── run-1.md, run-2.md...  # S9 — one per iteration
└── screenshots/
    └── run-{N}/
        ├── admin-login.png
        ├── stores-config.png
        ├── customers-grid.png
        └── ...
```

`scenarios.md` is regenerated each iteration but preserves the documented scenario set; only the
"Actual" and "Pass" columns change. `findings.md` is **append-only across iterations** — each
finding gets an ID (`F1`, `F2`, …) at first sight and the same ID is reused if it recurs.
