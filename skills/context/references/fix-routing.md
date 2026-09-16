# Fix Routing

Single source of truth for **who owns the remediation of a finding**. Every finding-producing
skill (`review`, `security`, `perf-audit`, `upgrade`, `lint`, `marketplace`, `a11y-audit`,
`breeze-compat`, and the consolidated `audit`) emits findings against the category vocabulary in
`findings-schema.md`; this file joins each `(producer, category)` pair to the skill that fixes it.

Routing is a **contract, not a judgement call**. Skills must not restate this table and must not
pick an executing skill ad hoc — resolve through `context/scripts/route-finding.sh`.

The human-readable tables below and the machine-readable block at the end of this file are the
same matrix. The block between the `ROUTING TABLE` markers is what `route-finding.sh` parses.

## Resolution signature

```
route-finding.sh --skill=<producer> --category=<cat> [--subcategory=<sub>]
                 [--severity=<sev>] [--confidence=<conf>] [--file=<path>]
  → {owner, rationale, gate}    gate ∈ auto | batch | manual
```

Output is one TSV line — `owner<TAB>gate<TAB>rationale` — and the exit status is always `0`.

`gate` governs how an item is handled **inside** an already-approved batch — it never replaces the
batch approval:

| gate | Meaning |
|------|---------|
| `batch` | Default. Executes once its batch is approved. |
| `auto` | Mechanical and idempotent (phpcbf style, safe rector transforms). Same as `batch`, but an
  all-`auto` batch may be pre-approved with `remediate --yes-auto` for unattended CI runs. |
| `manual` | **Never executed by `remediate`.** Emitted in the plan as a human action item with its
  rationale — credential rotation after a `security/secret`, PCI/GDPR sign-off, a `contrast`
  heuristic needing visual confirmation. Counted as neither closed nor attempted. |

`--file` is consulted only by the rows whose `condition` column needs it (marked ✳ below). A row
with no match yields `owner=unrouted`, which is an explicit bucket, never a silent drop.

## Matrix

**Producer: `review`**

| category | Owner | Condition |
|---|---|---|
| `architecture` | `feature --mode=extend` | ✳ `fix` when evidence is a single `file:line` and no `db_schema.xml` is touched |
| `security` | `fix` | |
| `performance` | `fix` | |
| `persistence` | `fix` | ✳ `feature --mode=extend` when evidence includes `db_schema.xml` |
| `di` | `extension-point` | ✳ `fix` unless subcategory ∈ {plugin, preference, interceptor} |
| `controllers` | `fix` | |
| `api` | `webapi` | ✳ `graphql` when evidence is under `Model/Resolver/` or `schema.graphqls` |
| `frontend` | `frontend` | ✳ `breeze-adapt` when `ctx.theme.breeze` |
| `admin` | `admin-form` | ✳ `admin-listing` when evidence matches `*_listing.xml`; `fix` otherwise |
| `cron` | `cli-command` | |
| `queue` | `message-queue` | |
| `testing` | `test-generate` | |
| `style`, `phpdoc` | `lint` | gate `auto` |
| `i18n` | `i18n` | |
| `csp` | `frontend` | ✳ `fix` when evidence is `etc/csp_whitelist.xml` |
| `dry-solid` | `lint` | ✳ `feature --mode=extend` when severity ≥ medium |
| `wcag` | `frontend` | |
| `pci`, `gdpr` | `fix` | gate `manual` — compliance classes require human sign-off |

**Producer: `security`**

| category | Owner | Condition |
|---|---|---|
| `cve`, `dep-audit` | `upgrade` | constraint bump, not a code patch |
| `secret` | `fix` | gate `manual` — **code removal does not rotate a burned credential**; the plan carries a mandatory human rotation action |
| `eqp` | `lint` | ✳ `fix` when subcategory is a security rule |
| `csrf`, `auth`, `session`, `cookie`, `acl` | `fix` | |
| `preference-collision` | `extension-point` | |
| `cron-ownership` | `cli-command` | |
| `graphql-auth` | `graphql` | |

**Producer: `perf-audit`**

| category | Owner |
|---|---|
| `n_plus_one`, `cache`, `slow_query`, `constructor-work`, `cache-identity`, `cache-lifetime` | `fix` |
| `indexer` | `indexer` |
| `queue` | `message-queue` |
| `plugin-hotpath` | `extension-point` |
| `cron-batch` | `cli-command` |
| `storefront-http` | `frontend` |

**Producer: `upgrade`** — every category (`deprecation`, `bc_break`, `magento_compat`,
`php_compat`, `composer_constraint`, `removed_class`, `removed_method`) → `upgrade`.

**Producer: `lint`**

| category | Owner | Gate |
|---|---|---|
| `style`, `dead-code`, `refactoring` | `lint` | `auto` |
| `complexity`, `type` | `lint` | `batch` |
| `surface` | by `subcategory` rule id, below | `batch` |

`surface` findings carry the rule id in `subcategory` (`lint/references/surface-invariants.md`):

| Rule | Owner |
|---|---|
| SI-01, SI-02, SI-03 | `message-queue` |
| SI-04, SI-05 | `fix` (cache.xml registration) |
| SI-06, SI-10 | `admin-listing` |
| SI-07, SI-08 | `admin-form` |
| SI-09, SI-12 | `fix` (acl.xml chain) — SI-09 is `critical` |
| SI-11 | `fix` (route/controller mismatch) |

**Producer: `marketplace`**

| category | Owner |
|---|---|
| `metadata`, `packaging` | **inline** — `remediate` edits these directly (deterministic, no behaviour change), the one inline-owned class, mirroring `review`'s existing "Inline — step 6 of this skill" row |
| `documentation` | `docs` |
| `testing` | `test-generate` |
| `eqp` | as `security/eqp` |

**Producer: `a11y-audit`** — every category (`alt-text`, `aria`, `semantic-html`, `keyboard`,
`contrast`, `forms`) → `frontend`. `contrast` gate `manual` (heuristic only, per the schema).

**Producer: `breeze-compat`**

| category | Owner |
|---|---|
| `requirejs`, `mixin`, `knockout`, `jquery-widget`, `assets` | `breeze-adapt` |
| `magento-init` | none — informational, per the schema |

## Defaults

Any `(producer, category)` pair absent from the matrix → `unrouted`, listed explicitly in the plan
with its producer and category so the gap is visible and the matrix can be extended. **Never a
silent default to `fix`.**

## Machine-readable matrix

Rows are evaluated **top to bottom, first match wins**, so a conditional row sits above its
unconditional fallback. Columns are TAB-separated:
`producer  category  subcategory  condition  owner  gate`

`subcategory` is `*` for any. `condition` is `-`, or one of
`file~<glob>` / `!file~<glob>` / `breeze` / `sev>=<level>`.

<!-- BEGIN ROUTING TABLE (parsed by route-finding.sh — TAB-separated, first match wins) -->
```tsv
review	architecture	*	-	feature	batch
review	security	*	-	fix	batch
review	performance	*	-	fix	batch
review	persistence	*	file~*db_schema.xml	feature	batch
review	persistence	*	-	fix	batch
review	di	plugin	-	extension-point	batch
review	di	preference	-	extension-point	batch
review	di	interceptor	-	extension-point	batch
review	di	*	-	fix	batch
review	controllers	*	-	fix	batch
review	api	*	file~*Model/Resolver/*	graphql	batch
review	api	*	file~*schema.graphqls	graphql	batch
review	api	*	-	webapi	batch
review	frontend	*	breeze	breeze-adapt	batch
review	frontend	*	-	frontend	batch
review	admin	*	file~*_listing.xml	admin-listing	batch
review	admin	*	file~*_form.xml	admin-form	batch
review	admin	*	-	fix	batch
review	cron	*	-	cli-command	batch
review	queue	*	-	message-queue	batch
review	testing	*	-	test-generate	batch
review	style	*	-	lint	auto
review	phpdoc	*	-	lint	auto
review	i18n	*	-	i18n	batch
review	csp	*	file~*csp_whitelist.xml	fix	batch
review	csp	*	-	frontend	batch
review	dry-solid	*	sev>=medium	feature	batch
review	dry-solid	*	-	lint	batch
review	wcag	*	-	frontend	batch
review	pci	*	-	fix	manual
review	gdpr	*	-	fix	manual
security	cve	*	-	upgrade	batch
security	dep-audit	*	-	upgrade	batch
security	secret	*	-	fix	manual
security	eqp	*	-	lint	batch
security	csrf	*	-	fix	batch
security	auth	*	-	fix	batch
security	session	*	-	fix	batch
security	cookie	*	-	fix	batch
security	acl	*	-	fix	batch
security	preference-collision	*	-	extension-point	batch
security	cron-ownership	*	-	cli-command	batch
security	graphql-auth	*	-	graphql	batch
perf-audit	n_plus_one	*	-	fix	batch
perf-audit	indexer	*	-	indexer	batch
perf-audit	cache	*	-	fix	batch
perf-audit	queue	*	-	message-queue	batch
perf-audit	slow_query	*	-	fix	batch
perf-audit	plugin-hotpath	*	-	extension-point	batch
perf-audit	constructor-work	*	-	fix	batch
perf-audit	cache-identity	*	-	fix	batch
perf-audit	cache-lifetime	*	-	fix	batch
perf-audit	cron-batch	*	-	cli-command	batch
perf-audit	storefront-http	*	-	frontend	batch
upgrade	deprecation	*	-	upgrade	batch
upgrade	bc_break	*	-	upgrade	batch
upgrade	magento_compat	*	-	upgrade	batch
upgrade	php_compat	*	-	upgrade	batch
upgrade	composer_constraint	*	-	upgrade	batch
upgrade	removed_class	*	-	upgrade	batch
upgrade	removed_method	*	-	upgrade	batch
lint	style	*	-	lint	auto
lint	dead-code	*	-	lint	auto
lint	refactoring	*	-	lint	auto
lint	complexity	*	-	lint	batch
lint	type	*	-	lint	batch
lint	surface	SI-01	-	message-queue	batch
lint	surface	SI-02	-	message-queue	batch
lint	surface	SI-03	-	message-queue	batch
lint	surface	SI-04	-	fix	batch
lint	surface	SI-05	-	fix	batch
lint	surface	SI-06	-	admin-listing	batch
lint	surface	SI-07	-	admin-form	batch
lint	surface	SI-08	-	admin-form	batch
lint	surface	SI-09	-	fix	batch
lint	surface	SI-10	-	admin-listing	batch
lint	surface	SI-11	-	fix	batch
lint	surface	SI-12	-	fix	batch
lint	surface	*	-	lint	batch
marketplace	metadata	*	-	inline	batch
marketplace	packaging	*	-	inline	batch
marketplace	documentation	*	-	docs	batch
marketplace	testing	*	-	test-generate	batch
marketplace	eqp	*	-	lint	batch
a11y-audit	alt-text	*	-	frontend	batch
a11y-audit	aria	*	-	frontend	batch
a11y-audit	semantic-html	*	-	frontend	batch
a11y-audit	keyboard	*	-	frontend	batch
a11y-audit	forms	*	-	frontend	batch
a11y-audit	contrast	*	-	frontend	manual
breeze-compat	requirejs	*	-	breeze-adapt	batch
breeze-compat	mixin	*	-	breeze-adapt	batch
breeze-compat	knockout	*	-	breeze-adapt	batch
breeze-compat	jquery-widget	*	-	breeze-adapt	batch
breeze-compat	assets	*	-	breeze-adapt	batch
breeze-compat	magento-init	*	-	none	manual
```
<!-- END ROUTING TABLE -->
