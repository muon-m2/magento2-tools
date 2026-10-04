# Phase 5 — Report (Detail)

Part of the `docs` skill — read at Phase 5 (Report).

#### Phase 5 — Report

Write a run report to
`{output_root}/docs-generated/{Vendor}_{Module}-{date}.md` listing:

- Module path documented.
- Docs produced (paths).
- New docs omitted (with reason, e.g. "user-guide omitted — no user surface found").
- Surface inventory: entries found per category.
- Surfaces omitted (not found in the module).
- Examples skipped due to unresolved types (list field names and the unresolved type).
- API description artifacts produced (paths), or the reason each was omitted.
- Any artifact **blocked** by the Phase 4 gate, naming the assertion and the matched text.
- Every `rest_warnings` entry, in the Phase 2 WARNING form.
- **Required follow-up** when a `.http` file was written: *add
  `docs/api/http-client.private.env.json` to the module `.gitignore` before committing.*
  The JetBrains HTTP Client writes your bearer token there and it sits beside the `.http`
  file, not inside `.idea/`, so a stock `.gitignore` does not cover it.
- Skill version: `docs@1.4.1`.
