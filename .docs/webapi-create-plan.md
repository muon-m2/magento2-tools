# magento2-webapi-create — Implementation Plan

**Goal:** Add `magento2-webapi-create`, the 20th skill — a dedicated REST/Web-API generator
(CRUD + optional custom actions) mirroring `graphql-create`, building on `module-create`'s
webapi templates.

**Verification gate (repo-native):** `bash tests/run-all.sh` green at the end (skill-count,
version-registry, placeholder-token, frontmatter, reference-integrity, template-lint).

---

## File structure

```
skills/magento2-webapi-create/
  SKILL.md                                  # Phase 0–5 spine (mirror graphql-create)
  references/
    service-contracts.md
    search-criteria.md
    auth-scopes.md
    error-handling.md
    extension-attributes.md
    webapi-testing.md
  templates/
    service-contract-interface.php          # from module-create api-interface.php + custom actions
    data-interface.php                       # from module-create dto-interface.php
    search-results-interface.php             # from module-create search-results-interface.php
    repository.php                            # from module-create repository.php (full impl)
    webapi.xml                               # from module-create webapi.xml + per-route auth + custom action
    di.xml                                   # three preferences
    acl.xml                                  # view/manage resource tree
    test-webapi-functional.php               # WebapiAbstract round-trip
```

Registration touchpoints (existing files to edit):
- `skills/magento2-context/references/skill-versioning.md` — add row.
- `README.md` — 19→20 (3 spots), Skills table row, dependency-graph edge.
- `docs/skills-reference.md` — per-skill entry.
- `CHANGELOG.md` — `[Unreleased]` Added bullet.

## Task breakdown

### Task 1 — Skill dir + SKILL.md
Create `skills/magento2-webapi-create/SKILL.md` mirroring `graphql-create/SKILL.md`: folded
`description` (≤1024), Core Rules, Workflow Phase 0–5, Inputs, Outputs, Reference Files,
Templates, Acceptance Criteria, Related Skills. Reference all 6 references + 8 templates by
the exact filenames above (reference-integrity test checks these resolve).

### Task 2 — Templates (8 files)
Author from the module-create sources (already read) + 3 new (di.xml, acl.xml, test). Resolve
tokens consistently; PK literal `entity_id`. Each `.php` must pass `php -l`, each `.xml`
`xmllint --noout`. Custom-action surface: a clearly-marked optional route block in webapi.xml +
matching method signature block in the service contract + repository stub.

### Task 3 — References (6 files)
Concise, authoritative markdown matching the graphql-create references' depth and voice. No
broken cross-refs.

### Task 4 — Registration + green suite
Edit the 4 touchpoints. `README` 19→20 everywhere (skill-count-consistency asserts every
"N skills" equals `ls -d skills/*/ | wc -l` = 20 after Task 1). Add skill-versioning row,
skills-reference entry, CHANGELOG bullet, dependency edge. Run `bash tests/run-all.sh` → green.

### Task 5 — Final review + commit + PR
Self-review the whole skill against the spec + graphql-create parity. Commit. Push. Open PR
off main. Then (separate pipeline step) handle Copilot review on #20 + this PR, cut release.

## Self-review checklist (run after Task 4)
- [ ] `ls -d skills/*/ | wc -l` == 20 and every README "N skills" says 20.
- [ ] skill-versioning.md has a webapi-create row.
- [ ] All 6 references + 8 templates referenced in SKILL.md exist (reference-integrity).
- [ ] All template tokens registered in placeholder-schema.md.
- [ ] `bash tests/run-all.sh` exit 0.
