# Template Inventory

Part of the `module-create` skill — read at Step 4 (when picking a template for a file type).

`templates/` contains a template for every file type any surface can produce. When generating any
file, look up its template via `references/surfaces.md`. Do not invent file content from prose.

Templates added in v2 (use these for new surfaces):

- Admin UI: `admin-ui-component-listing.xml`, `admin-ui-component-form.xml`,
  `admin-listing-layout.xml`, `admin-form-layout.xml`, `admin-ui-data-provider.php`,
  `admin-ui-column-actions.php`, `admin-routes.xml`, `menu.xml`
- Frontend UI: `frontend-routes.xml`, `frontend-route-handler.php`, `frontend-layout.xml`,
  `frontend-template.phtml`
- REST API: `webapi.xml`
- GraphQL: `schema.graphqls`, `graphql-resolver.php`, `graphql-batch-resolver.php`
- Cron: `crontab.xml`, `cron-job.php`
- Queue: `communication.xml`, `queue_consumer.xml`, `queue_topology.xml`, `queue_publisher.xml`,
  `consumer.php`
- Extensions: `plugin.php`, `di-plugin.xml`, `observer.php`, `events.xml`, `data-patch.php`,
  `schema-patch.php`
- EAV: the attribute patches are owned by the **`eav-attribute`** skill (the single
  source — its copies carry the `getAttribute()` idempotency guard). Use
  `eav-attribute/templates/eav-add-{product,customer,category}-attribute-patch.php`;
  this skill keeps only the supporting `source-model.php`, `backend-model.php`.
- Email: `email-template.html`, `email_templates.xml`
- Tests: `test-controller.php`, `test-observer.php`, `test-plugin.php`, `test-resolver.php`,
  `test-repository.php`
- MFTF (auto-added when a UI surface is declared): `mftf-test.xml` →
  `Test/Mftf/Test/{Vendor}{ModuleName}SmokeTest.xml`, `mftf-actiongroup.xml` →
  `Test/Mftf/ActionGroup/`. A minimal admin smoke test so Marketplace functional-coverage is non-zero.
- Compliance (always created): `LICENSE.txt` (proprietary EULA — swap for the SPDX license text when
  the composer `license` field is an SPDX id), `gitignore` (write to module root as `.gitignore`). The
  per-file copyright header is **not** a template — the shared
  `context/scripts/add-license-headers.sh` stamps it in Step 5 (see
  `context/references/module-hygiene.md`).
