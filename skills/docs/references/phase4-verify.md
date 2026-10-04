# Phase 4 — Verify (Detail)

Part of the `docs` skill — read at Phase 4 (Verify).

#### Phase 4 — Verify

Before saving any file:

- No unsubstituted `{tokens}` remain in the output.
- Internal links (e.g. `[API Surface](#api-surface)`) resolve within the document.
- No section contains an empty table or placeholder text such as "N/A" or "fill me in".
- Confirm the skill has not written or modified any `.php`, `.xml`, `.phtml`, `.less`,
  `.js` or `.graphqls` file, nor anything outside `{module}/docs/`,
  `{module}/README.md`, `{module}/CHANGELOG.md`, and `{output_root}/docs-generated/`.
- Every JSON example block parses as valid JSON (mental parse or `jq` check).
- Every example block carries the caption `> Example — illustrative, generated from the schema`.
- Every ` ```mermaid ``` ` block is properly fenced, brace/arrow-balanced, and uses
  sanitized node ids (no spaces or special characters).
- No `![]` image embeds appear anywhere in the output.
- The `{DOCUMENTATION_LINKS}` token in `README.md` lists only the docs that were
  actually produced in this run (registered in
  `context/references/placeholder-schema.md`).
- `openapi.yaml` parses as YAML and every `.json` artifact parses as JSON.
