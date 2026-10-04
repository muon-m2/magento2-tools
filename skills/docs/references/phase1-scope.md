# Phase 1 — Scope (Detail)

Part of the `docs` skill — read at Phase 1 (Scope).

#### Phase 1 — Scope

Determine:

1. **Which module** — from the user's request or via `--module=Vendor_Module`.
   Resolve the absolute module path.
2. **Which docs to produce** — any combination of:
   - `readme`               → `{module}/README.md`
   - `technical-reference`  → `{module}/docs/technical-reference.md`
   - `developer-guide`      → `{module}/docs/developer-guide.md`
   - `user-guide`           → `{module}/docs/user-guide.md`            (only if a user surface exists)
   - `api-reference`        → `{module}/docs/api-reference.md`         (only if REST routes exist)
   - `graphql-reference`    → `{module}/docs/graphql-reference.md`     (only if GraphQL operations exist)
   - `changelog`            → `{module}/CHANGELOG.md` (scaffold only; no history invented)
   - `openapi`              → `{module}/docs/api/openapi.yaml`               (only if REST routes exist)
   - `http-client`          → `{module}/docs/api/{slug}.http`
                            + `{module}/docs/api/http-client.env.json`       (only if REST routes exist)
   - `postman`              → `{module}/docs/api/postman/{slug}.postman_collection.json`
                            + `{module}/docs/api/postman/{slug}.postman_environment.json`
                                                                             (only if REST routes exist)
   Default: produce every applicable doc. Omit `user-guide` when no user surface is
   present; omit `api-reference`, `openapi`, `http-client` and `postman` when no REST
   routes exist; omit `graphql-reference` when no GraphQL operations are found.

   `http-client.env.json` is emitted if and only if `{slug}.http` is.
   `{slug}` is derived in `references/doc-structure.md` → *REST API Description
   Artifacts*; it is what a consumer already sees in the URL, so the spec file, the
   collection and the endpoint stay greppable by one string.

   **GraphQL has no derivative artifact.** `etc/schema.graphqls` is already
   machine-readable and already checked in; generating a second copy of it would only
   create something to drift.
