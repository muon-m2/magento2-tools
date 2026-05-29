# MFTF Test Patterns

Magento Functional Testing Framework — Selenium-based admin UI tests.

## File Layout

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Mftf/
├── ActionGroup/
├── Data/
├── Page/
├── Section/
└── Test/
```

## Section (page object)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sections xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:noNamespaceSchemaLocation="urn:magento:mftf:Page/etc/SectionObject.xsd">
    <section name="{Vendor}{Entity}ListingSection">
        <element name="addNewButton" type="button" selector="#add"/>
        <element name="firstRowEditLink" type="button" selector="//tr[1]//a[contains(@class,'edit')]"/>
        <element name="searchField" type="input" selector="input[name='keyword']"/>
    </section>
</sections>
```

## Page

```xml
<?xml version="1.0" encoding="UTF-8"?>
<pages xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="urn:magento:mftf:Page/etc/PageObject.xsd">
    <page name="{Vendor}{Entity}ListingPage" url="{vendor_lower}_{module_lower}/{entity_lower}/index"
          area="admin" module="{Vendor}_{Module}">
        <section name="{Vendor}{Entity}ListingSection"/>
    </page>
</pages>
```

## Listing Test

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tests xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="urn:magento:mftf:Test/etc/testSchema.xsd">
    <test name="{Vendor}{Entity}ListingRendersTest">
        <annotations>
            <features value="{Vendor}_{Module}"/>
            <stories value="Listing"/>
            <title value="Admin listing for {Entity} renders without error"/>
            <description value="Verify the {Entity} listing page loads successfully."/>
            <severity value="MAJOR"/>
            <group value="{Vendor}_{Module}"/>
        </annotations>
        <before>
            <actionGroup ref="AdminLoginActionGroup" stepKey="login"/>
        </before>
        <after>
            <actionGroup ref="AdminLogoutActionGroup" stepKey="logout"/>
        </after>

        <amOnPage url="{{_ENV.MAGENTO_BACKEND_NAME}}/{vendor_lower}_{module_lower}/{entity_lower}/index" stepKey="goToListing"/>
        <waitForPageLoad stepKey="waitForListing"/>
        <seeElement selector="{{ {Vendor}{Entity}ListingSection.addNewButton }}" stepKey="seeAddNew"/>
    </test>
</tests>
```

## Add / Edit / Delete Test Pattern

```xml
<test name="{Vendor}{Entity}AddNewTest">
    <before>
        <actionGroup ref="AdminLoginActionGroup" stepKey="login"/>
    </before>
    <after>
        <actionGroup ref="{Vendor}Delete{Entity}ActionGroup" stepKey="cleanup"/>
        <actionGroup ref="AdminLogoutActionGroup" stepKey="logout"/>
    </after>

    <amOnPage url="{{_ENV.MAGENTO_BACKEND_NAME}}/{vendor_lower}_{module_lower}/{entity_lower}/new" stepKey="newPage"/>
    <waitForPageLoad stepKey="waitForNew"/>
    <fillField selector="{{ {Vendor}{Entity}FormSection.nameField }}" userInput="MFTF-Created" stepKey="setName"/>
    <click selector="{{ {Vendor}{Entity}FormSection.saveButton }}" stepKey="save"/>
    <seeInCurrentUrl url="/{vendor_lower}_{module_lower}/{entity_lower}/index" stepKey="seeListing"/>
    <see userInput="MFTF-Created" stepKey="seeRow"/>
</test>
```

## Running MFTF

```bash
{ctx.runner} vendor/bin/mftf run:test {Vendor}{Entity}ListingRendersTest
{ctx.runner} vendor/bin/mftf run:group {Vendor}_{Module}
```

MFTF requires a running Magento instance with a configured Selenium grid. If MFTF is
unavailable, mark MFTF tests as skipped and report it as an environment limitation.

## Anti-Patterns

- **Hardcoded admin credentials in test XML.** Use `{{_ENV.MAGENTO_ADMIN_USERNAME}}` /
  `_ENV.MAGENTO_ADMIN_PASSWORD`.
- **No cleanup in `<after>`.** Every test that creates state must remove it.
- **CSS selectors that match unrelated elements.** Prefer `[data-test-id=...]` over
  `.btn-primary` — the latter is fragile across themes.
