# Documentation Format Rules

Apply these rules when generating `README.md` and `CHANGELOG.md` for any module.
Use `templates/README.md` and `templates/CHANGELOG.md` as the structural base.

---

## README.md Structure

`README.md` must cover these sections in order:

1. **Purpose** — one paragraph describing what the module does and why it exists
2. **Features** — bullet list of capabilities
3. **Installation** — ordered steps:
   ```bash
   bin/magento module:enable {Vendor}_{ModuleName}
   bin/magento setup:upgrade
   bin/magento setup:di:compile
   bin/magento cache:flush
   ```
   When `persistence` surface is declared, add the whitelist regeneration step:
   ```bash
   bin/magento setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleName}
   ```
4. **Configuration** — Admin path (`Stores → Configuration → {Section}`) and key config fields
5. **Public API** — Links to `Api/` interfaces when REST or GraphQL surfaces are declared
6. **Dependencies** — Other Magento modules and third-party packages required
7. **Known Limitations** — Any intentional constraints or out-of-scope behavior

**Writing rules:**

- Write in plain English. No marketing language.
- Omit sections that genuinely do not apply (e.g. skip Configuration if there are no config fields).
- Replace all `{placeholders}` before marking the task complete.

---

## CHANGELOG.md Format

Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format exactly.

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - YYYY-MM-DD

### Added
- Initial module scaffold
```

**Section order within each version:** Added → Changed → Deprecated → Removed → Fixed → Security.
Omit sections that have no entries for that version. Replace `YYYY-MM-DD` with the actual date.
