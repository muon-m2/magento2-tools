# magento2-tools documentation

Developer documentation for the `magento2-tools` Claude Code plugin — 18 skills covering
the full Magento 2 engineering lifecycle: scaffolding, review, testing, bug-fixing,
deployment, auditing, upgrading, and releasing.

## Reading order

| You are… | Start here |
|----------|------------|
| Trying the toolkit for the first time | [Getting started](getting-started.md) |
| Using it on an existing project, day to day | [Daily workflows](daily-workflows.md) |
| Bootstrapping a brand-new Magento 2 project or module | [New project guide](new-project-guide.md) |
| Looking for how a skill works internally (phases, gates, artifacts) | [Flows and scenarios](flows-and-scenarios.md) |
| Looking up a flag, phase list, or output path | [Skills reference](skills-reference.md) |
| Setting up overrides, `CLAUDE.md` hints, or CI integration | [Configuration](configuration.md) |

## The documents

- **[Getting started](getting-started.md)** — prerequisites, installation, verifying the
  plugin, the safety model (read-only skills vs. approval gates), and three safe first
  commands to run against any Magento 2 project.
- **[Daily workflows](daily-workflows.md)** — recipe-style guide for routine work:
  fixing a bug, implementing a feature, reviewing hand-written changes, generating tests,
  debugging, deploying, translating, releasing, and periodic audits. Each recipe lists
  what happens, where the approval gates are, and which artifacts are produced.
- **[New project guide](new-project-guide.md)** — step-by-step path from an empty
  `app/code/` to a scaffolded, reviewed, tested, deployed, and releasable first module,
  including team enablement and CI wiring.
- **[Flows and scenarios](flows-and-scenarios.md)** — the deep dive: architecture
  (hub-and-spoke around `magento2-context`), per-skill phase flows with diagrams, the
  approval-gate map, the artifact map, and six end-to-end scenario walkthroughs.
- **[Skills reference](skills-reference.md)** — one compact section per skill:
  invocation, flags, phases, outputs, related skills.
- **[Configuration](configuration.md)** — the context resolver and its cache,
  environment variables (`M2_PHP_CONTAINER`, `M2_MAGENTO_ROOT`, `M2_CACHE_TTL`),
  `.claude/m2.json`, `CLAUDE.md` hints the skills honor, and CI integration
  (validate-only deploys, JSON/SARIF findings).

## Contributing to the toolkit itself

The repository [README](../README.md) covers the repo layout, the contract-test harness
(`bash tests/run-all.sh`), and skill versioning. Skill versions live in
`skills/magento2-context/references/skill-versioning.md`; the plugin version lives in
`.claude-plugin/plugin.json` (see [CHANGELOG.md](../CHANGELOG.md)).
