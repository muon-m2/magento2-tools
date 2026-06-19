# Runtime pa11y Pass (OPT-IN)

The runtime pa11y pass extends the static scan with browser-rendered accessibility
testing. It is **strictly opt-in** and degrades gracefully to an honest gap when
unavailable.

Cross-references:
- Static check catalog: `references/wcag-rules.md`
- Finding shape: `magento2-context/references/findings-schema.md`
- Severity scale: `magento2-context/references/severity.md`

---

## When the Runtime Pass Runs

All three conditions must be true simultaneously:

1. The `--runtime` flag is passed by the user.
2. The user provides `--url=<storefront-url>` (a live, accessible storefront URL).
3. `pa11y` is listed as available in `{ctx.tools}` (resolved by `magento2-context`).

If **any** condition is unmet, the runtime pass is skipped entirely. A `scanner_errors`
entry is added to the findings document explaining which condition was not met:

```json
{
  "scanner": "pa11y",
  "stderr": "runtime pass skipped — pa11y not found in {ctx.tools}"
}
```

or

```json
{
  "scanner": "pa11y",
  "stderr": "runtime pass skipped — no --url provided"
}
```

**The static-only result is always reported honestly.** Static findings are never
withheld or marked as pending the runtime pass.

---

## Running pa11y

When all conditions are met, run:

```bash
pa11y --reporter json <url>
```

Or, for multiple URLs with a config file:

```bash
pa11y-ci --json --config pa11y-ci.json
```

Capture stdout as JSON. pa11y's JSON reporter emits an array of issue objects per URL.

### Timeout and Error Handling

- Use `--timeout 30000` (30 s) to avoid hangs on slow storefronts.
- If pa11y exits non-zero (network error, timeout, parse error), add a `scanner_errors`
  entry and continue with static findings only.
- If the URL returns a non-2xx HTTP status, record it in `scanner_errors` and skip.

---

## Mapping pa11y Issues to the Findings Schema

pa11y issue fields → findings-schema.md fields:

| pa11y field | Findings schema field | Notes |
|------------|----------------------|-------|
| `type` (`error`/`warning`/`notice`) | `severity` | error→`high`, warning→`medium`, notice→`low` |
| `code` (WCAG rule code, e.g. `WCAG2AA.Principle1...`) | `subcategory` | Extract WCAG SC from the code |
| `message` | `title` | Truncate to one line |
| `context` (HTML snippet) | `evidence[].snippet` | |
| `selector` (CSS selector) | `evidence[].file` + note | Prefix with `<url>:css-selector:` |
| — | `category` | Always `"accessibility"` |
| — | `tags` | `["wcag", "pa11y", "runtime"]` |
| — | `recommendation` | Derived from WCAG technique or pa11y message |

Assign a unique `id` in the form `a11y-{seq:04d}` (continuing the sequence from static
findings).

### Severity Mapping

| pa11y `type` | Finding `severity` |
|-------------|-------------------|
| `error`     | `high`            |
| `warning`   | `medium`          |
| `notice`    | `low`             |

---

## Merging Static and Runtime Findings

1. Run the static scan first (Phase 2 of the skill workflow).
2. Run pa11y and collect runtime findings.
3. Deduplicate: if a runtime finding matches a static finding on the same element and
   same rule, keep the static finding (it carries file:line evidence) and add the
   pa11y selector as additional evidence.
4. Append remaining runtime-only findings to the findings array.
5. Tag runtime findings with `"source": "runtime"` in their `tags` array.
6. The `tools` top-level field in the output document should record:
   ```json
   {"pa11y": "executed", "static-scan": "executed"}
   ```
   or
   ```json
   {"pa11y": "unavailable", "static-scan": "executed"}
   ```

---

## Honest-Gap Behaviour

| Condition | What the skill does |
|-----------|---------------------|
| `--runtime` not passed | Runtime pass silently skipped (no `scanner_errors` entry; it is not an error to not opt in) |
| `--runtime` passed, `pa11y` absent | Add `scanner_errors` entry; proceed with static-only; state clearly in Markdown report |
| `--runtime` passed, no URL | Add `scanner_errors` entry; proceed with static-only |
| pa11y exits non-zero | Add `scanner_errors` entry with stderr; static findings still reported |
| URL returns 4xx/5xx | Add `scanner_errors` entry; do not fabricate runtime findings |

The Markdown report must include a **Runtime pass status** section that states one of:
- "Runtime pass: not requested (static-only results)."
- "Runtime pass: completed via pa11y. N additional issues found."
- "Runtime pass: SKIPPED — [reason]. Results are static-only."

---

## pa11y Version and Standard

- Requires pa11y ≥ 6.x (supports `--reporter json`).
- Default standard: `WCAG2AA` (matches the skill's WCAG 2.1 Level AA scope).
- Pass `--standard WCAG2AA` explicitly to ensure consistent results across pa11y
  versions.

---

## Security Note

The URL passed via `--url` is provided by the user and used only as a pa11y argument.
Never pass the URL to any other system, do not follow redirects to external hosts, and
do not transmit credentials via the URL (use pa11y's `--auth` or `--config` for
authenticated scans). Never store the URL in the findings JSON.
