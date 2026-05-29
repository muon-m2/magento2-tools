# Changelog

All notable changes to the `magento2-tools` plugin. The plugin is versioned as a unit;
individual skill versions are tracked in
`skills/magento2-context/references/skill-versioning.md`.

This project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — unreleased

First packaged release: the `magento2-*` skills collection as an installable Claude Code
plugin distributed via the `muon` marketplace (this repo).

### Added
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` — the repo is its own
  marketplace; skills auto-discovered from `skills/`.
- Per-project environment overrides for `magento2-context`: `M2_PHP_CONTAINER` /
  `M2_MAGENTO_ROOT` env vars and `.claude/m2.json` (`php_container`, `magento_root`).
- Reference-integrity test now validates `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`
  script paths.

### Changed
- **Portability:** removed the hardcoded `battlefield-php` container name; runner detection
  now resolves via env > `.claude/m2.json` > generic name patterns. Magento root detects
  `.`-vs-`src` layout instead of assuming `src`. (`magento2-context` 1.1.0 → 1.2.0.)
- Script defaults (preflight, build-findings, secret/cve/cross-module scans) auto-detect
  `app/code` / `composer.lock` rather than assuming `src/`.
- Doc/template path examples use `{ctx.magento_root}/app/code` instead of `src/app/code`.
- Bundled-script invocations in SKILL.md use `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`.
- Repo layout: skills moved to top-level `skills/`, harness to `tests/`.
- LF line endings enforced via `.gitattributes`.

Skill names retain the `magento2-` prefix (collision safety); plugin invocation is
`magento2-tools:magento2-<skill>`.
