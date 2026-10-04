# Phase 7 — Documentation and Final Report

Part of the `feature` skill — read at Phase 7 start.

Phase 7 is split into two sub-phases: **7A** (documentation — required) and **7B** (final report).
**Phase 7B may not start until Phase 7A's documentation set is written to disk and current.** The
report is the genuine last step; documentation is produced — and verified complete — before it.

---

## Phase 7A — Documentation (required)

**Goal:** produce — or refresh — the feature's complete documentation set so it reflects the code
as actually built.

Load `references/documentation-guide.md`. It defines the required artifacts per scope, the per-mode
documentation scope, screenshot sourcing, API payload examples, and the completeness gate. Phase 7A
is **mandatory** in `feature` and `extend` modes, **reduced** in `hotfix` mode, and **skipped** in
`spike` mode (see `references/modes.md`).

1. **Per-module technical docs.** For every module created or modified this run, delegate to
   `docs` to (re)generate `{module}/README.md`,
   `{module}/docs/technical-reference.md`, and the `CHANGELOG.md` scaffold from the module's own
   code. Re-running it is how the extracted `@api`/event/config surface stays current.

   ```
   Skill: docs
   Args: --module={Vendor}_{Module} --docs-root=.docs/{FeatureName}
   ```

2. **Technical specification.** Write or refresh `.docs/{FeatureName}/spec.md` — the cross-module
   technical reference (architecture, data model, module interactions, extension points,
   sequence/flow diagrams in Mermaid). Link to the per-module references rather than restating them.

3. **Developer-scope overview.** Write or refresh `guides/developer-guide.html` — the HTML overview
   that links to the per-module docs generated in step 1 (each module's `docs/developer-guide.md`):
   service contracts, events, plugins, DI, and worked code examples showing how the modules **compose**
   as a feature. Cross-link into each module's own developer guide for its per-module detail — do not
   re-author or duplicate that content here. When the feature exposes a REST or GraphQL surface, embed
   request/response payload examples (reuse the raw S2 captures under
   `.docs/{FeatureName}/smoke/raw/S2/` where available) and also save curated, redacted examples under
   `api-examples/`.

4. **User-scope overview.** Write or refresh `user-docs/user-guide.html` — the HTML overview that
   links to the per-module docs generated in step 1 (each module's `docs/user-guide.md`, when
   present): admin configuration and end-user workflows across the feature, **with screenshots**.
   Cross-link into each module's own user guide for its per-module detail — do not re-author or
   duplicate that content here. Reuse the Phase 6B screenshots under
   `.docs/{FeatureName}/smoke/screenshots/` (copy the relevant ones into `user-docs/screenshots/`),
   or capture fresh ones with the smoke browser driver for screens smoke did not exercise.

5. **Other helpful artifacts** (as the module's scope warrants): a Postman collection for the REST
   surface, an ER diagram, a sequence diagram, or sample payloads/fixtures. Save under `artifacts/`.
   Omit any that do not apply — do not create empty placeholders.

6. **Updated, not stale.** On a resume or `extend` run, **refresh** existing documents to match the
   final code — never leave a previously generated doc describing an earlier design. Apply the
   feature's shared CSS color schema inline to every HTML file (per the Core Rules).

7. Run the completeness checklist in `references/documentation-guide.md` — including that each HTML
   overview's cross-links into the per-module docs resolve to files that exist on disk. **Do not
   proceed to Phase 7B until every required artifact for the current mode exists on disk.**

---

## Phase 7B — Final Report

**Goal:** produce a complete implementation report.

1. Load `references/final-report-format.md`.
2. Use `templates/final-report.md` as the structural base.
3. Fill in all 10 sections:
    - Executive Summary
    - Modules Implemented (table)
    - Public API Index
    - Configuration Guide
    - Tradeoffs (load `references/tradeoffs-catalog.md` and document applicable ones)
    - Deviations from Blueprint
    - Test Coverage Summary
    - Known Limitations
    - Recommended Next Steps
    - Smoke Test Results (per `references/final-report-format.md` §10 — omit in `spike` mode)
4. Update the blueprint status line to `Status: Complete` in `.docs/{FeatureName}/blueprint.md`.
   Update the plan status and mark all remaining checkboxes `[x]` in `.docs/{FeatureName}/plan.md`.
5. Save the report to `.docs/{FeatureName}/report.md`.
6. Link the Phase 7A documentation set from the report (in Recommended Next Steps or an artifacts
   list): `spec.md`, the developer and user guides, `api-examples/` (when present), and the
   per-module `README.md` / `docs/technical-reference.md`.
7. **Verify artifact collection.** For every sub-skill invoked this run, confirm its
   category dir exists under `.docs/{FeatureName}/` (e.g. `reviews/`, `tests/`,
   `deployments/`). If any expected artifact is missing or was written to a global
   `.docs/{category}/` instead, note it as a collection gap in the report and (if the
   file exists globally) move it under the feature folder.
8. Print the report to the conversation.
9. State explicitly: *"Feature implementation complete. See report above,
   `.docs/{FeatureName}/report.md`, and the documentation set under `.docs/{FeatureName}/`."*

After 7B, if the request named more than one spec, run the **Multi-spec requests** ask from `SKILL.md` (Phase 1) before ending.

---

- `templates/final-report.md`: implementation report template (incl. Section 10).
