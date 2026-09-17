# Skill Versioning

Versions live in each skill's `SKILL.md` frontmatter (`version:`) — that is the single
source of truth. The table below is GENERATED from the frontmatter by
`context/scripts/gen-versions.sh`; edit the frontmatter, then regenerate.
Every saved artefact (review report, blueprint, plan, task file, deploy report, audit
report) must record the contributing skill versions so older artefacts remain
re-interpretable when skills evolve.

Per-release change narrative lives in the repository `CHANGELOG.md` — the durable
record of what changed and why. This file records only who is at which version and
the rules for bumping.

## Current Versions

<!-- BEGIN GENERATED: versions (gen-versions.sh) -->
| Skill           | Version |
|-----------------|---------|
| a11y-audit      | 1.1.1   |
| admin-form      | 1.1.2   |
| admin-listing   | 1.1.3   |
| audit           | 1.1.0   |
| breeze-adapt    | 1.0.2   |
| breeze-compat   | 1.1.0   |
| breeze-theme    | 1.0.2   |
| cli-command     | 1.1.2   |
| context         | 1.15.0  |
| data-migration  | 1.3.2   |
| debug           | 1.3.1   |
| deploy          | 1.5.0   |
| docs            | 1.4.1   |
| eav-attribute   | 1.3.2   |
| extension-point | 1.1.2   |
| feature         | 2.15.2  |
| fix             | 1.3.0   |
| frontend        | 1.0.6   |
| graphql         | 1.0.6   |
| i18n            | 1.3.0   |
| indexer         | 1.1.2   |
| lint            | 1.4.1   |
| marketplace     | 1.1.0   |
| message-queue   | 1.1.3   |
| module-create   | 1.10.3  |
| perf-audit      | 1.2.0   |
| release         | 1.2.1   |
| remediate       | 1.0.0   |
| review          | 2.4.1   |
| security        | 2.0.0   |
| system-config   | 1.1.3   |
| test-generate   | 1.2.1   |
| triage          | 1.0.0   |
| upgrade         | 1.2.0   |
| webapi          | 1.0.3   |
| widget          | 1.0.0   |
<!-- END GENERATED: versions -->

## Header Format

Single-skill artefact:

```
Skill version: {Skill}@{Version}
```

Multi-skill artefact (preferred — explicit about every contributor):

```
Skill versions:
  - {LeadSkill}@{Version}
  - {ContributingSkillA}@{Version}
  - {ContributingSkillB}@{Version}
  - context@{Version}
```

Substitute concrete values from the table above when writing an artefact. The
registry-consistency test recognises these tokens as placeholders and does not
flag them as drift.

## Semver Rules

| Bump  | Trigger                                                                                             |
|-------|-----------------------------------------------------------------------------------------------------|
| Major | Removed checklist categories, changed JSON schema in a backward-incompatible way, removed CLI flags |
| Minor | New checklist category, new mode, new template, new optional flag                                   |
| Patch | Bugfix only — no behaviour change to outputs                                                        |

Bumping a skill means editing this file AND updating any template strings that emit the
version (`templates/feature-blueprint.md`, `templates/final-report.md`,
`templates/plan.md`, `references/report-template.md`, `templates/report.html`).

## Why This Matters

Saved reports include the skill version that produced them. Future re-reads can detect
mismatch and either re-run with current skills or explicitly preserve historical
interpretation. The version is the contract for "this report's findings mean what those
rules meant at that time."
