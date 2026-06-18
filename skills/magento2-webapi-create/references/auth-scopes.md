# Auth Scopes

Every `<route>` in `webapi.xml` declares a `<resources>` block. That block is the authorization
gate — it decides who may call the endpoint. There is no "no auth" option; the closest is the
explicit `anonymous` resource.

## The three scopes

| Scope | `<resources>` | Who can call | Use for |
|-------|---------------|--------------|---------|
| **ACL-protected** (default) | `<resource ref="{Vendor}_{ModuleName}::view"/>` (read) / `::manage` (write) | Admin user / integration token whose role grants that ACL resource | Admin-managed data, integration endpoints |
| **Self** | `<resource ref="self"/>` | The authenticated customer, scoped to their own data | Customer-owned resources (the token identifies the user) |
| **Anonymous** | `<resource ref="anonymous"/>` | Anyone, no token | Truly public reads only — requires explicit justification |

## ACL-protected (the default)

Reads use `::view`, writes use `::manage`. Both ids must exist in `etc/acl.xml`. The caller is an
admin user or an integration whose role has been granted the resource. This is the right default
for anything an admin or a server-to-server integration manages.

## Self

`self` resolves the customer from the bearer token and is the pattern for customer-owned data. The
endpoint must enforce ownership: a `self`-scoped `getById` must verify the loaded entity belongs to
the current customer (via `Magento\Authorization\Model\UserContextInterface::getUserId()`), or a
customer could read another customer's record by guessing an id. `self` controls *who is
authenticated*, not *which row they may touch* — you still check the row.

## Anonymous — handle with care

`anonymous` exposes the route to the public internet with no credential. Only acceptable for
read-only, non-sensitive data (e.g. a public catalog of store locations). Never anonymous for:
- any write (`POST`/`PUT`/`DELETE`),
- anything returning PII, prices tied to a customer, stock that leaks business data, or internal ids.

This skill requires an explicit justification before generating an anonymous route, and prints a
warning in the Phase 5 report.

## Tokens (how callers authenticate)

- **Admin/integration token** — `POST /V1/integration/admin/token` or a configured Integration; the
  token's role determines which ACL resources (and thus routes) it can reach.
- **Customer token** — `POST /V1/integration/customer/token`; satisfies `self` routes.

A route protected by `::manage` is invisible to a token whose role lacks that resource — the Web API
returns 401/403 before the service method runs.
