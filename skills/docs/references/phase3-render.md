# Phase 3 — Render (Detail)

Part of the `docs` skill — read at Phase 3 (Render).

#### Phase 3 — Render

Fill the chosen templates with extracted facts:

- `${CLAUDE_SKILL_DIR}/templates/readme.md` → `{module}/README.md`
- `${CLAUDE_SKILL_DIR}/templates/technical-reference.md` → `{module}/docs/technical-reference.md`
- `${CLAUDE_SKILL_DIR}/templates/developer-guide.md` → `{module}/docs/developer-guide.md`
- `${CLAUDE_SKILL_DIR}/templates/user-guide.md` → `{module}/docs/user-guide.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/api-reference.md` → `{module}/docs/api-reference.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/graphql-reference.md` → `{module}/docs/graphql-reference.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/changelog-scaffold.md` → `{module}/CHANGELOG.md`

Follow the section order, example-derivation rules, error-model conventions,
screenshot-appendix format, and Mermaid recipes defined in
`${CLAUDE_SKILL_DIR}/references/doc-structure.md`.

**API description artifacts** are not composed by hand. Run
`${CLAUDE_SKILL_DIR}/scripts/emit-api-artifacts.sh` with `MODULE_PATH`, the
`SURFACE_FILE` from Phase 2, and `FORMATS` set to the selected subset of
`openapi,http-client,postman`. It fills these five templates:

- `${CLAUDE_SKILL_DIR}/templates/openapi.yaml` → `{module}/docs/api/openapi.yaml`
- `${CLAUDE_SKILL_DIR}/templates/http-client.http` → `{module}/docs/api/{slug}.http`
- `${CLAUDE_SKILL_DIR}/templates/http-client.env.json` → `{module}/docs/api/http-client.env.json`
- `${CLAUDE_SKILL_DIR}/templates/postman-collection.json` → `{module}/docs/api/postman/{slug}.postman_collection.json`
- `${CLAUDE_SKILL_DIR}/templates/postman-environment.json` → `{module}/docs/api/postman/{slug}.postman_environment.json`

The script — not the model — owns this rendering because the artifacts must be
**byte-identical across runs** (that is what makes them reviewable in a PR, and why the
Postman collection id is a UUIDv5 derived from `{Vendor}_{Module}` rather than random).
It runs the Phase 4 secret/privacy gate itself and returns a JSON report naming what it
wrote, what it blocked and why, and the `rest_warnings` it carried through. Its exit
code is `0` for a clean run, `2` when at least one artifact was blocked, `1` on a hard
error. Generation rules per format are in `references/doc-structure.md` → *REST API
Description Artifacts*.

Each table row in the technical reference must include the source file path so readers
can verify the documentation against the code.
