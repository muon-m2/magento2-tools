# Shared Findings Schema

Single source of truth for the JSON document emitted by every finding-producing skill:
`magento2-module-review`, `magento2-security-audit`, `magento2-performance-audit`,
`magento2-module-upgrade`.

A SARIF 2.1.0 emitter is generated from the same JSON; adding new finding categories only
requires updating this schema and the JSON emitter.

## Top-Level Object

```json
{
  "schemaVersion": "1.0",
  "skill": "magento2-module-review",
  "skillVersion": "2.3.0",
  "skillVersions": [
    "magento2-module-review@2.3.0",
    "magento2-context@1.6.0"
  ],
  "outputKind": "review",
  "target": {
    "module": "Acme_OrderS3Export",
    "path": "src/app/code/Acme/OrderS3Export",
    "scope": "module"
  },
  "runAt": "2026-05-26T14:30:00Z",
  "mode": "full",
  "context": {
    "vendor": "Acme",
    "magento_version": "2.4.7-p1",
    "edition": "open-source",
    "php_version": "8.2.15",
    "runner": "docker compose exec -T -u magento php"
  },
  "summary": {
    "total": 12,
    "bySeverity": {
      "critical": 0,
      "high": 1,
      "medium": 4,
      "low": 5,
      "info": 2
    },
    "byCategory": {
      "security": 3,
      "performance": 2,
      "architecture": 4,
      "style": 3
    }
  },
  "findings": [
    { "...see Finding Object below..." }
  ],
  "skipped": [
    {
      "check": "PHPStan level 8",
      "reason": "vendor/bin/phpstan not present"
    }
  ],
  "scanner_errors": [
    {
      "scanner": "cve-scan",
      "stderr": "composer audit produced no output (composer error or no network) — dependency advisories were NOT checked"
    }
  ],
  "tools": {
    "phpcs": "executed",
    "phpstan": "unavailable",
    "phpunit": "executed",
    "xmllint": "executed"
  }
}
```

## Finding Object

```json
{
  "id": "review-2026-05-23-001",
  "severity": "high",
  "category": "security",
  "subcategory": "csrf",
  "title": "POST controller missing form key validation",
  "description": "The admin controller AcceptsPostOnly does not implement HttpPostActionInterface or call FormKeyValidator::validate().",
  "evidence": [
    {
      "file": "Controller/Adminhtml/Order/Save.php",
      "line": 47,
      "endLine": 64,
      "snippet": "public function execute()..."
    }
  ],
  "recommendation": "Implement HttpPostActionInterface and inject FormKeyValidator. Reject requests where FormKeyValidator::validate() returns false.",
  "verification": "Re-run review or run vendor/bin/phpunit Test/Unit/Controller/SaveTest.php",
  "cwe": "CWE-352",
  "tags": ["magento-architecture", "security", "csrf"]
}
```

## Required Fields per Finding

| Field          | Required | Notes                                                                                                                                              |
|----------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| id             | Yes      | Slug `{skill-short}-{date}-{seq}` — must be unique per run                                                                                         |
| severity       | Yes      | `critical`, `high`, `medium`, `low`, `info`                                                                                                        |
| category       | Yes      | Skill-specific top-level grouping; see per-skill table below                                                                                       |
| confidence     | No       | `confirmed`, `candidate`, `needs-triage`. Default: `confirmed` for AST/composer-audit findings, `candidate` for regex hits or non-`live` CVE data. |
| title          | Yes      | One-line summary                                                                                                                                   |
| description    | No       | Multi-sentence explanation                                                                                                                         |
| evidence       | Yes      | Array; at least one `{file, line}` entry                                                                                                           |
| recommendation | Yes      | Concrete fix                                                                                                                                       |
| verification   | Yes      | How to confirm the fix                                                                                                                             |
| subcategory    | No       | Free-form sub-grouping                                                                                                                             |
| cwe            | No       | CWE identifier when applicable (security findings)                                                                                                 |
| cve            | No       | CVE identifier (security audit; dependency CVE findings)                                                                                           |
| bulletin_url   | No       | Authoritative source URL (Adobe bulletin, OSV record, …)                                                                                           |
| source         | No       | Object: `{path, status}` describing the data file the finding was derived from. When `status != "live"`, `confidence` MUST NOT be `confirmed`.     |
| tags           | No       | Free-form labels for filtering                                                                                                                     |

## Top-Level Fields the Emitter Adds

| Field         | Required | Notes                                                                                 |
|---------------|----------|---------------------------------------------------------------------------------------|
| skill         | Yes      | `SKILL_NAME` env var; the producing skill identifier.                                 |
| skillVersion  | Yes      | `SKILL_VERSION` env var.                                                              |
| skillVersions | Yes      | Array of `name@version` strings — every contributor.                                  |
| outputKind    | Yes      | `review` \| `security` \| `performance` \| `upgrade`. Drives output filename + label. |
| target        | Yes      | `{module, path, scope}`. `scope` ∈ `module                                            |site|vendor|diff`. |
| runAt         | Yes      | ISO-8601 UTC timestamp.                                                               |
| mode          | Yes      | `full` \| `quick` \| `diff`.                                                          |
| context       | Yes      | Subset of `magento2-context` JSON pinned at run time.                                 |
| summary       | Yes      | Aggregated counts by severity and category.                                           |
| findings      | Yes      | Array; per-skill semantics.                                                           |
| skipped       | Yes      | Array of skipped checks with reason.                                                  |
| scanner_errors | Yes     | Array of `{scanner, stderr}`. One entry per scanner that crashed or degraded. This is how "scanner found nothing" is distinguished from "scanner did not run" — a degraded scanner records here instead of silently emitting an empty findings list. Emit `[]` when every scanner ran cleanly. Asserted by `tests/test-audit-builders.sh`. |
| tools         | Yes      | Object reporting which CLI tools ran or were unavailable.                             |

## Per-Skill Category Vocabulary

### magento2-module-review

`architecture` | `security` | `performance` | `persistence` | `di` | `controllers` |
`api` | `frontend` | `admin` | `cron` | `queue` | `testing` | `style` | `phpdoc` |
`i18n` | `csp` | `dry-solid` | `wcag` | `pci` | `gdpr`

### magento2-security-audit

`cve` | `secret` | `eqp` | `dep-audit` | `csrf` | `auth` | `session` | `cookie` |
`acl` | `preference-collision` | `cron-ownership` | `graphql-auth`

### magento2-performance-audit

`n_plus_one` | `indexer` | `cache` | `queue` | `slow_query` | `plugin-hotpath` |
`constructor-work` | `cache-identity` | `cache-lifetime` | `cron-batch` |
`storefront-http`

### magento2-module-upgrade

`deprecation` | `bc_break` | `magento_compat` | `php_compat` | `composer_constraint` |
`removed_class` | `removed_method`

## SARIF 2.1.0 Mapping

| Schema field                        | SARIF field                             |
|-------------------------------------|-----------------------------------------|
| skill                               | tool.driver.name                        |
| skillVersion                        | tool.driver.version                     |
| findings[].id                       | results[].ruleId                        |
| findings[].title                    | results[].message.text (first line)     |
| findings[].severity (critical/high) | results[].level = "error"               |
| findings[].severity (medium)        | results[].level = "warning"             |
| findings[].severity (low/info)      | results[].level = "note"                |
| findings[].evidence[0].file/line    | results[].locations[0].physicalLocation |
| findings[].cwe                      | results[].taxa[].id (taxonomies = CWE)  |

The SARIF emitter is a thin transformer over this JSON. Adding a new finding category in
the JSON propagates to SARIF automatically.

## File Naming

JSON output:

```
.docs/reviews/{Vendor}_{Module}-review-{YYYY-MM-DD}.json
.docs/audits/security-{scope}-{YYYY-MM-DD}.json
.docs/audits/perf-{scope}-{YYYY-MM-DD}.json
.docs/upgrades/{Vendor}_{Module}-{from}-to-{to}-{YYYY-MM-DD}.json
```

All paths are anchored at the project root (`{ctx.docs_root}` = `{project_root}/.docs`) —
never under `{ctx.magento_root}`, `app/code`, or a module directory. See the **Artifact
location** rule in `magento2-context/SKILL.md`.

SARIF output: same path, `.sarif` extension.

## Schema Versioning

Bump `schemaVersion` when:

- Removing or renaming a required field (major: 2.0)
- Changing the semantics of an existing field (major: 2.0)
- Adding a new required field (minor: 1.1)
- Adding a new optional field (no bump)

Skills consuming the JSON must read `schemaVersion` and degrade gracefully on minor-version
mismatch (skip unknown fields). Major-version mismatch is a hard error.
