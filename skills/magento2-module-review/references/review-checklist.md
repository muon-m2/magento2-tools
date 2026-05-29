# Magento 2 Module Review Checklist

Use this checklist to evaluate confirmed pass/fail/needs-review items. Keep findings evidence-based and cite
files/lines.

Areas are grouped by risk tier. Spend review budget in tier order: complete Tier 1 before moving to Tier 2, and Tier 2
before Tier 3. Any Critical or High finding in an earlier tier should be reported immediately rather than held until the
full checklist is done.

---

## Tier 1 — Must Review First (highest production and security risk)

Failures in these areas can cause exploitable vulnerabilities, data loss, broken deployments, or irrecoverable schema
damage. Always covered, including in Quick Review mode.

### Security

- No raw secrets, tokens, passwords, session IDs, or unnecessary PII in logs.
- Tokens use CSPRNG, are stored hashed where possible, expire, and are single-use for authentication flows.
- Authorization and account-state checks happen before irreversible state changes where practical.
- Public auth flows avoid email/user enumeration.
- Rate limiting or abuse control exists for public auth, account, coupon, search, upload, and API flows.
- File upload/import code validates type, path, extension, size, permissions, and storage location.
- SQL, HTML, JS, command, path traversal, SSRF, XXE, insecure deserialization, and unsafe unserialize risks are checked.
- External HTTP calls have timeouts, TLS validation, error handling, and no secret leakage.

### Persistence And Setup

- Declarative schema is used for modern modules.
- Tables have primary keys, needed unique constraints, indexes for query patterns, and foreign keys where appropriate.
- Schema whitelist is present when required.
- Data/schema patches are idempotent and version-independent.
- Resource models use Magento DB adapters and bind/quote values safely.
- Raw SQL is justified, parameterized, and isolated.
- Data retention and cleanup exist for tokens, logs, queues, imports, generated artifacts, and transient state.
- Install/update operations do not assume existing data shape without checks.

### Dependency Injection

- Constructors use dependency injection, not service locator patterns.
- Direct `ObjectManager` usage is absent except justified framework edge cases.
- Preferences are limited to owned interfaces or deliberate substitutions.
- Plugins avoid broad or hot-path interception when observers, events, service composition, or layout/config extension
  points are safer.
- Area-specific DI is used where dependencies only apply to `frontend`, `adminhtml`, `webapi_rest`, `graphql`, or
  `crontab`.
- Heavy/session/context dependencies use proxies where premature initialization matters.
- Virtual types are understandable and named for purpose.

### Controllers, Routing, And CSRF

- Controllers implement appropriate HTTP action interfaces.
- POST/PUT/DELETE state changes validate form keys or implement explicit CSRF behavior.
- GET actions do not mutate state.
- Redirect and result factories are used correctly.
- Customer/admin authorization is explicit.
- User-facing errors are localized and do not leak sensitive details.
- Redirect URLs are validated to avoid open redirects.

### Service Contracts And APIs

- Public `Api` interfaces are stable and documented.
- Public data interfaces use Magento extensible-data patterns when intended for third-party extension.
- Internal contracts are marked internal or kept out of public API documentation.
- Repositories expose coherent aggregate persistence and avoid leaking security-sensitive internals.
- `webapi.xml` routes use intentional ACL resources; anonymous access is rare and justified.
- API input/output types avoid raw arrays where DTOs or explicit scalar contracts are more stable.
- GraphQL resolvers validate auth, store scope, and input, and avoid expensive per-item loading.

---

## Tier 2 — Should Review (important architectural areas)

Failures here cause maintainability debt, subtle runtime errors, admin exposure, or performance degradation. Cover in
full reviews; skip in Quick Review mode unless a Tier 1 finding points here.

### Registration And Packaging

- Module name follows `Vendor_Module`.
- `registration.php` uses `Magento\Framework\Component\ComponentRegistrar::MODULE`.
- `etc/module.xml` declares necessary sequence dependencies.
- Modern modules avoid obsolete setup-version assumptions unless supporting legacy upgrade paths.
- `composer.json` uses `type: magento2-module`, PSR-4 autoload, files autoload for `registration.php`, realistic
  PHP/Magento constraints, and valid license metadata.
- README or package docs explain installation, configuration, behavior, public APIs, limitations, and operational notes.

### Admin Configuration And ACL

- `system.xml` fields have labels, scope flags, validation, source/backend models where needed.
- Sensitive fields use encrypted backend models and are not exposed in logs.
- ACL resources are granular and referenced by admin routes/config.
- Defaults in `config.xml` are production-safe, especially for auth, payment, admin, security, and external
  integrations.
- Config paths are named consistently and read through scoped config APIs.

### Frontend, Layout, And Templates

- PHTML output is escaped with `$escaper` for HTML, attributes, URLs, and JS contexts.
- Blocks/templates avoid business logic and service lookups.
- View models implement `Magento\Framework\View\Element\Block\ArgumentInterface`.
- Layout XML uses extension points before overrides.
- JS follows Magento RequireJS conventions where applicable.
- Email templates escape variables and declare template vars.
- Translatable phrases are wrapped consistently.
- CSS/LESS/JS assets are scoped to avoid storefront-wide side effects.

### Performance And Scalability

- Queries use indexes and avoid loading full collections unnecessarily.
- Collection iteration is chunked for large datasets.
- Cron and consumers are idempotent and can resume safely.
- Cache usage has explicit identities/tags where relevant.
- Expensive work is avoided in constructors, plugins, observers, layout generation, and request bootstrap.
- Synchronous remote calls on storefront critical paths have timeouts and fallbacks.

### Testing

Criteria are tagged `[static]` (assessable by reading files) or `[runtime]` (requires test runner — report as
Skipped when tools are unavailable; do not infer Pass from file existence alone).

- `[static]` Test files exist in `Test/Unit/` for service, controller, repository, and view-model classes.
- `[static]` Test class structure uses `setUp(): void`, typed mocks, and `createMock()` — not `getMockBuilder()`.
- `[static]` Test names describe behaviour, not implementation (e.g., `testThrowsWhenOrderNotFound` not `testGet`).
- `[static]` Tests do not hard-code credentials, local paths, or environment-specific state.
- `[runtime]` Unit tests cover service logic, controllers, repositories, config, view models, cron, and failure paths.
- `[runtime]` Integration tests exist for DB schema, repositories, plugins, observers, DI, and framework behavior.
- `[runtime]` API/GraphQL tests exist for public endpoints.
- `[runtime]` Security-sensitive flows have negative tests and race/idempotency tests where possible.

---

## Tier 3 — Review When Present (compliance and quality)

Failures here are Low or Medium unless they break a release gate. Skip areas that are structurally absent from the
module (e.g., no frontend assets → CSP not applicable). Always verify applicability before marking Pass.

### Internationalisation

- All user-facing strings use `__('text')` for translation.
- Template output combines translation and escaping: `$escaper->escapeHtml(__('text'))`.
- `i18n/en_US.csv` exists and covers all translatable phrases in the module.
- No user-facing strings are hardcoded in PHP or PHTML without `__()`.
- Translation keys are stable identifiers; dynamic string interpolation avoids breaking key extraction.

### Content Security Policy

- `etc/csp_whitelist.xml` exists when the module loads external JS, CSS, fonts, images, or makes browser-initiated API
  calls.
- All external origins are whitelisted by explicit `<value type="host">` entries under the appropriate policy directive.
- `unsafe-inline` and `unsafe-eval` are absent; violations are reported as High findings.
- Inline scripts or styles in PHTML are replaced with RequireJS modules or external files where CSP compliance is
  required.
- File is absent only when the module has no external resource dependencies; justify in a comment when omitted
  deliberately.

### Accessibility (WCAG)

Apply when the module has `frontend_ui` or `admin_ui` surface. See `references/tier3-checks.md`
for the full pattern list.

- All `<img>` elements have `alt` attributes (or `alt=""` for decorative).
- All form inputs have associated `<label>` elements.
- All `<button>` elements have accessible text (visible or `aria-label`).
- Headings follow a logical order (no skipping h1 → h3).
- Color contrast meets WCAG AA in LESS variables (manual / automated verification).
- Focus indicators visible (`:focus` styles defined).
- No autoplay media without controls.
- Click handlers on interactive elements only (`<button>`, `<a>`, not `<div>`).

### Plugin / Preference Collision

Apply when the module has `di.xml` or `crontab.xml`. See `references/tier3-checks.md`.

- No conflicting `<preference for="X"/>` between this module and other custom modules.
- Plugins targeting hot-path methods document their `sortOrder`.
- Cron job names don't collide with another module's job.
- Module `<sequence>` graph is acyclic.

### PCI Scope

Apply when the module touches payment data. See `references/tier3-checks.md`.

- Card data (PAN, CVV, expiry) is never stored in plain text.
- Full PAN is never logged.
- Custom encryption is not used for cardholder data (use Magento Crypt).
- No hardcoded merchant API keys in source.
- Plugins on payment classes document their purpose.

### GDPR Data Retention

Apply when the module touches customer PII. See `references/tier3-checks.md`.

- PII columns are encrypted at rest where the schema supports it.
- PII is not logged in plain text.
- New tables holding PII have a documented retention policy.
- Right-to-erasure honored (module observes `customer_delete` or equivalent event).
- PII export available (admin-only) for GDPR Article 15 (right of access).
