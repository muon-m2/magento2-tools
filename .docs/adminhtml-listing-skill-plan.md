# `magento2-adminhtml-listing` Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the 19th skill — `magento2-adminhtml-listing` — an adminhtml UI-component grid generator mirroring `magento2-adminhtml-form`, with the **listing naming contract** (5-place data-source name agreement) as its baked-in correctness guarantee.

**Architecture:** A self-contained skill under `skills/magento2-adminhtml-listing/`. It lifts `module-create`'s proven listing-stub templates into the skill (refined for the naming contract), adds the pieces a full grid needs (mass-action controllers, listing layout, an optional SearchResult performance path), wraps them in an `adminhtml-form`-style phased `SKILL.md` + references + a `verify-listing.sh`, and registers everywhere (versioning, README 18→19, docs, CHANGELOG). Default DataProvider wiring = `AbstractDataProvider` + `CollectionFactory` (suite-consistent); `SearchResult` + `di` map is optional.

**Tech Stack:** Magento 2 adminhtml ui_component XML + PHP, the repo's template-lint contract tests, `tests/run-all.sh`.

**Reference:** spec `.docs/adminhtml-listing-skill-design.md`. **Sibling sources to copy/mirror** (read them during the task): `skills/magento2-module-create/templates/{admin-ui-component-listing.xml, admin-ui-data-provider.php, admin-ui-column-actions.php, admin-controller-index.php, admin-listing-layout.xml, admin-routes.xml, acl.xml, menu.xml}`; `skills/magento2-adminhtml-form/{SKILL.md, scripts/verify-form.sh, references/*}`. Placeholder tokens are the registered ones in `placeholder-schema.md` (`{Vendor}`, `{ModuleName}`, `{EntityName}`, `{vendor_lower}`, `{module_lower}`, `{entity}`, `{entities}`) — reuse exactly; do NOT introduce new tokens (the `test-placeholder-tokens` lint forbids unregistered tokens).

---

### Task 1: Skill templates

**Files:** create `skills/magento2-adminhtml-listing/templates/*`.

- [ ] **Step 1: Scaffold dirs.** `mkdir -p skills/magento2-adminhtml-listing/{templates,references,scripts}`.

- [ ] **Step 2: Lift the 4 existing listing templates from `module-create`** (copy verbatim, then apply the small edits below). Each must keep the registered placeholder tokens.
  - `templates/listing.xml` ← `module-create/templates/admin-ui-component-listing.xml`. Edits: in the `<massaction>`, add a second action `enable`/`disable` toggle pointing at `*/*/massStatus` (or keep just delete if status isn't modeled — leave a commented toggle example). Confirm the **5-place naming contract** holds verbatim (js_config provider, deps dep, dataSource name, dataProvider name, columns spinner all use `{vendor_lower}_{module_lower}_{entity}_listing` / `…_data_source` / `…_columns`).
  - `templates/data-provider.php` ← `module-create/templates/admin-ui-data-provider.php` (verbatim — the `AbstractDataProvider` default).
  - `templates/column-actions.php` ← `module-create/templates/admin-ui-column-actions.php` (verbatim — edit/delete row URLs).
  - `templates/controller-index.php` ← `module-create/templates/admin-controller-index.php` (verbatim — renders the grid).

- [ ] **Step 3: Lift acl/menu/routes** from `module-create` (these are created-if-absent / reused-from-form at generation time):
  - `templates/acl.xml` ← `module-create/templates/acl.xml`
  - `templates/menu.xml` ← `module-create/templates/menu.xml`
  - `templates/routes.xml` ← `module-create/templates/admin-routes.xml`

- [ ] **Step 4: Author `templates/layout-index.xml`** (the listing page layout — adapt `module-create/templates/admin-listing-layout.xml`; it must add the `{vendor_lower}_{module_lower}_{entity}_listing` uiComponent to the `content` block). Verbatim target:
```xml
<?xml version="1.0"?>
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <update handle="styles"/>
    <body>
        <referenceContainer name="content">
            <uiComponent name="{vendor_lower}_{module_lower}_{entity}_listing"/>
        </referenceContainer>
    </body>
</page>
```
(If `admin-listing-layout.xml` already matches this, copy it; otherwise write the above.)

- [ ] **Step 5: Author the mass-action controllers** (no exact sibling — write verbatim).

`templates/controller-mass-delete.php`:
```php
<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\Controller\ResultInterface;
use Magento\Ui\Component\MassAction\Filter;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Mass-delete selected {EntityName} records.
 */
class MassDelete extends Action implements HttpPostActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';

    /**
     * @param \Magento\Backend\App\Action\Context $context
     * @param \Magento\Ui\Component\MassAction\Filter $filter
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     */
    public function __construct(
        Context $context,
        private readonly Filter $filter,
        private readonly CollectionFactory $collectionFactory,
    ) {
        parent::__construct($context);
    }

    /**
     * @return \Magento\Framework\Controller\ResultInterface
     */
    public function execute(): ResultInterface
    {
        $collection = $this->filter->getCollection($this->collectionFactory->create());
        $deleted = 0;
        foreach ($collection as $item) {
            $item->delete();
            $deleted++;
        }
        $this->messageManager->addSuccessMessage(__('A total of %1 record(s) have been deleted.', $deleted));

        $resultRedirect = $this->resultRedirectFactory->create();
        return $resultRedirect->setPath('*/*/');
    }
}
```

`templates/controller-mass-status.php` (enable/disable toggle — generated only when the entity has a status field):
```php
<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Controller\Adminhtml\{EntityName};

use Magento\Backend\App\Action;
use Magento\Backend\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\Controller\ResultInterface;
use Magento\Ui\Component\MassAction\Filter;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory;

/**
 * Mass enable/disable selected {EntityName} records. Set the status value via di.xml argument
 * `status` (1 = enable, 0 = disable) on two virtualTypes, or pass it through a shared base.
 */
class MassStatus extends Action implements HttpPostActionInterface
{
    public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';

    /**
     * @param \Magento\Backend\App\Action\Context $context
     * @param \Magento\Ui\Component\MassAction\Filter $filter
     * @param \{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\CollectionFactory $collectionFactory
     * @param int $status
     */
    public function __construct(
        Context $context,
        private readonly Filter $filter,
        private readonly CollectionFactory $collectionFactory,
        private readonly int $status = 1,
    ) {
        parent::__construct($context);
    }

    /**
     * @return \Magento\Framework\Controller\ResultInterface
     */
    public function execute(): ResultInterface
    {
        $collection = $this->filter->getCollection($this->collectionFactory->create());
        $count = 0;
        foreach ($collection as $item) {
            $item->setData('status', $this->status);
            $item->save();
            $count++;
        }
        $this->messageManager->addSuccessMessage(__('A total of %1 record(s) have been updated.', $count));

        return $this->resultRedirectFactory->create()->setPath('*/*/');
    }
}
```

- [ ] **Step 6: Author the OPTIONAL performance-path templates.**

`templates/di-listing.xml` (used only when the SearchResult path is chosen):
```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:ObjectManager/etc/config.xsd">
    <type name="Magento\Framework\View\Element\UiComponent\DataProvider\CollectionFactory">
        <arguments>
            <argument name="collections" xsi:type="array">
                <item name="{vendor_lower}_{module_lower}_{entity}_listing_data_source" xsi:type="string">{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid\Collection</item>
            </argument>
        </arguments>
    </type>
    <virtualType name="{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid\Collection" type="Magento\Framework\View\Element\UiComponent\DataProvider\SearchResult">
        <arguments>
            <argument name="mainTable" xsi:type="string">{vendor_lower}_{module_lower}_{entity}</argument>
            <argument name="resourceModel" xsi:type="string">{Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}</argument>
        </arguments>
    </virtualType>
</config>
```

`templates/grid-collection.php` (concrete SearchResult subclass, when a virtualType won't do):
```php
<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName}\Grid;

use Magento\Framework\View\Element\UiComponent\DataProvider\SearchResult;

/**
 * Grid collection for the {EntityName} listing (SearchResult-based; supports joins).
 */
class Collection extends SearchResult
{
    /**
     * @return void
     */
    protected function _initSelect(): void
    {
        parent::_initSelect();
        // Add joins here, e.g. $this->getSelect()->join(...);
    }
}
```
NOTE on the optional path: when the SearchResult path is used, `listing.xml`'s inner `<dataProvider class=...>` is swapped to `Magento\Framework\View\Element\UiComponent\DataProvider\DataProvider` and `di-listing.xml` + the collection are emitted; otherwise the default `{EntityName}DataProvider` is used and neither optional file is emitted. The SKILL.md documents this switch.

- [ ] **Step 7: Author `scripts/verify-listing.sh`** mirroring `adminhtml-form/scripts/verify-form.sh`, but scanning listing paths: `*/view/adminhtml/ui_component/*_listing.xml`, `*/view/adminhtml/layout/*.xml`, `*/etc/adminhtml/*.xml`, `*/etc/{acl,di}.xml` for xmllint; and `*/Controller/Adminhtml/*`, `*/Ui/DataProvider/*DataProvider.php`, `*/Ui/Component/Listing/Column/*.php`, `*/Model/ResourceModel/*/Grid/Collection.php` for `php -l`. Same structure/flags as verify-form.sh (set -uo pipefail, skip-if-tool-absent, scan-all-then-exit). `chmod +x`.

- [ ] **Step 8: Lint the templates locally and commit.**
```bash
# XML well-formedness + PHP lint on the templates (they contain placeholder tokens, which are
# valid PHP identifiers / XML text, so php -l and xmllint pass — same as the form skill's templates).
for x in skills/magento2-adminhtml-listing/templates/*.xml; do xmllint --noout "$x" || echo "BAD $x"; done
for p in skills/magento2-adminhtml-listing/templates/*.php; do php -l "$p" >/dev/null || echo "BAD $p"; done
bash tests/run-all.sh | tail -3   # template-lint + placeholder-token tests must stay green
git add skills/magento2-adminhtml-listing/templates skills/magento2-adminhtml-listing/scripts
git commit -m "feat(adminhtml-listing): skill templates + verify script"
```
Expected: no `BAD` lines; suite `FAIL: 0`. **If `test-placeholder-tokens.sh` flags an unregistered token, STOP** — either reuse a registered token or (only if truly new) the token must be added to `placeholder-schema.md` in Task 3; report it.

---

### Task 2: SKILL.md + references

**Files:** create `skills/magento2-adminhtml-listing/SKILL.md` + `references/*.md`.

- [ ] **Step 1: Write `SKILL.md`** by mirroring `skills/magento2-adminhtml-form/SKILL.md` section-for-section (read it first). Required sections & content:
  - **Frontmatter `description`:** "Generate a Magento 2 adminhtml UI-component **listing/grid** — the declarative `ui_component/{entity}_listing.xml` plus its DataProvider, columns, actions column, and mass actions, wired to an existing edit form. Use when the user wants to add or scaffold an admin grid, a data grid, a listing page, grid columns, filters, mass actions, or an actions column in the Magento admin. Detects edition and flags Commerce-only grid features. Produces files that pass magento2-module-review with zero Critical/High findings." (Keep ≤ 1024 chars; add the routing discriminator vs `adminhtml-form` / `module-create` if PR #17's pattern has merged — otherwise a short "for the edit form use magento2-adminhtml-form" line.)
  - **Core Rules:** the **listing naming contract** (5-place agreement — quote the formula from spec §3); default `AbstractDataProvider` wiring, optional `SearchResult`; reuse the form's acl/menu/routes if present; never assume a running Magento instance; edition gating.
  - **Workflow:** Phase 0 Context (resolve via `magento2-context`) → 1 Resolve Inputs (entity, columns, has-status?, paired form? performance path?) → 2 Plan → 3 **Test First, then Generate** (RED: assert the grid renders rows + the naming contract holds; then emit templates) → 4 Verify (`verify-listing.sh`) → 5 Report.
  - **Inputs / Outputs / Reference Files / Templates / Acceptance Criteria / Common Pitfalls Handled / Related Skills** — mirror the form skill. Templates section lists the Task-1 files. Related: pairs with `magento2-adminhtml-form`; `module-create` defers here for standalone grids.

- [ ] **Step 2: Write the 9 references** (prose; mirror the depth/style of `adminhtml-form/references/*`):
  - `listing-xml-anatomy.md` — dataSource/toolbar/columns structure; the 5-place naming contract spelled out.
  - `dataprovider-wiring.md` — the default `AbstractDataProvider` path vs the optional `SearchResult`+di path; when to use which; the empty-grid pitfall.
  - `columns-and-types.md` — text/select/date/actions columns, filters, options sources.
  - `mass-actions.md` — selectionsColumn + massaction + the MassDelete/MassStatus controllers + the Filter pattern.
  - `grid-collection.md` — the SearchResult collection (joins, mainTable/resourceModel).
  - `controllers-and-routing.md` — Index + mass controllers, ADMIN_RESOURCE, routes.
  - `edition-differences.md` — any OS-vs-Commerce grid notes (e.g. nothing Commerce-only for a basic grid; flag if so).
  - `pairing-with-form.md` — how the actions column / Add-New button target the form's `new`/`edit`/`delete` routes; reusing acl/menu/routes.
  - `pitfalls.md` — empty grid (name mismatch), missing selectionsColumn ⇒ mass actions inert, actions column wrong `indexField`, DataProvider not returning grid shape.

- [ ] **Step 3: Verify cross-refs + commit.**
```bash
bash tests/run-all.sh | tail -3   # reference-integrity + skill-frontmatter must pass
git add skills/magento2-adminhtml-listing/SKILL.md skills/magento2-adminhtml-listing/references
git commit -m "feat(adminhtml-listing): SKILL.md workflow + reference docs"
```
Expected: `FAIL: 0`; `test-reference-integrity.sh` (any `${CLAUDE_SKILL_DIR}` / `magento2-<skill>` refs resolve) and `test-skill-frontmatter.sh` (description ≤ 1024, well-formed) PASS.

---

### Task 3: Registration (19th skill)

**Files:** modify `skills/magento2-context/references/skill-versioning.md`, `README.md`, `docs/skills-reference.md`, `docs/README.md`, `CHANGELOG.md` (+ any other "N skills" prose the count-guard flags).

- [ ] **Step 1: skill-versioning.md** — add a row `| magento2-adminhtml-listing | 1.0.0 | New template/column type, mass-action change, wiring change |` to the Current Versions table, and a changelog note. (`test-version-registry-consistency.sh` expects every skill dir to have a row.)

- [ ] **Step 2: README** — add a row to the Skills table (`| magento2-adminhtml-listing | Scaffold an adminhtml grid/listing (listing XML + DataProvider + columns + mass actions). |`); add it to the dependency graph (`adminhtml-listing ──► context, module-create, module-review`); and update **every "N skills" count 18 → 19** (the table intro "18 skills", the Layout comment "18 magento2-* skills", and anywhere else). `test-skill-count-consistency.sh` enforces all prose counts == 19.

- [ ] **Step 3: docs** — add a per-skill entry to `docs/skills-reference.md`; bump `docs/README.md`'s "18 skills" → 19; add a row to the "Choosing between adjacent skills" table if present (adminhtml grid → this; edit form → adminhtml-form).

- [ ] **Step 4: CHANGELOG `[Unreleased]`** — add an **Added** bullet describing the new skill (mirror the form skill's 1.7.0 entry style).

- [ ] **Step 5: Verify + commit.**
```bash
ls -d skills/*/ | wc -l            # 19
grep -rnE '[0-9]+ (magento2-\* )?skills?' README.md docs/README.md  # all say 19
bash tests/run-all.sh | tail -4    # FAIL: 0 — incl. count-consistency==19 + version-registry
git add skills/magento2-context/references/skill-versioning.md README.md docs/ CHANGELOG.md
git commit -m "docs(adminhtml-listing): register 19th skill (versioning, README, docs, CHANGELOG)"
```
Expected: 19; all counts 19; `FAIL: 0` with `test-skill-count-consistency.sh` + `test-version-registry-consistency.sh` PASS.

---

### Task 4: Final verification

- [ ] **Step 1: Full suite + clean tree.** `bash tests/run-all.sh | tail -6 && git status --short`. Expect `FAIL: 0` (every template-lint, placeholder-token, frontmatter, reference-integrity, count-guard@19, version-registry PASS); working tree only the pre-existing untracked entries.
- [ ] **Step 2: verify-listing.sh smoke** against a throwaway rendered tree:
```bash
tmp="$(mktemp -d)"; root="$tmp/app/code/Acme/Faq"
mkdir -p "$root/view/adminhtml/ui_component" "$root/Controller/Adminhtml/Faq" "$root/Ui/DataProvider" "$root/etc"
# render a couple templates with trivial token substitution and confirm verify passes
sed -e 's/{Vendor}/Acme/g; s/{ModuleName}/Faq/g; s/{EntityName}/Faq/g; s/{vendor_lower}/acme/g; s/{module_lower}/faq/g; s/{entity}/faq/g; s/{entities}/faqs/g' \
    skills/magento2-adminhtml-listing/templates/listing.xml > "$root/view/adminhtml/ui_component/acme_faq_faq_listing.xml"
bash skills/magento2-adminhtml-listing/scripts/verify-listing.sh "$root" Faq; echo "exit=$?"
rm -rf "$tmp"
```
Expected: `OK:` line, exit 0 (xmllint validates the rendered listing XML).
- [ ] **Step 3: Scope check.** `git diff --stat $(git merge-base HEAD main)..HEAD` → only the new skill dir + the registration files (skill-versioning, README, docs, CHANGELOG). No other skill's behaviour changed.

---

## Self-review

**Spec coverage** (`.docs/adminhtml-listing-skill-design.md`):
- §2 scope + AbstractDataProvider-default wiring → Task 1 (templates) with the optional SearchResult path (Step 6).
- §3 naming contract → baked into `listing.xml` (Step 2) + SKILL.md Core Rules + `verify-listing.sh`.
- §4 components (templates, references, verify) → Tasks 1–2; registration footprint → Task 3.
- §5 contract tests stay green → verified each task + Task 4.
- §8 versioning/docs → Task 3.

**Placeholder scan:** novel templates (mass controllers, di-listing, grid-collection, layout) are verbatim; lifted templates are "copy sibling X" (a concrete, real file); references are prose specs mirroring the form skill (prose, not code). No "TBD". All placeholder tokens are the registered ones from `placeholder-schema.md`.

**Type/name consistency:** the 5-place naming contract (`{vendor_lower}_{module_lower}_{entity}_listing` / `…_data_source` / `…_columns`) is used identically in `listing.xml`, the SKILL.md Core Rules, the di-listing optional path, and the references; class names (`{EntityName}DataProvider`, `{EntityName}Actions`, `MassDelete`/`MassStatus`, `Grid\Collection`) match across templates, di, and references.
