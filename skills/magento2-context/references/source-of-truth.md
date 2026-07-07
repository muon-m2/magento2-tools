# Source of Truth for Code Generation

Consumed by every `magento2-*` skill that **generates** code or files. Read this when a generator
must decide *where* a convention, shape, or wiring comes from. Read-only audit/review skills do not
use this file — they scan `app/code` by design.

## Source-of-Truth hierarchy

To generate any file, consult these sources in order and stop at the first that answers:

1. **Skill templates** (`templates/`) — the structural base for every file type the skill emits.
2. **Shared references** — `naming.md`, `php-coding-style.md`, `creation-checklist.md`,
   `surfaces.md`, `phpdoc-rules.md`, and the skill's own `references/`.
3. **Baked-in Magento 2 knowledge** — framework classes and contracts (`AbstractModel`,
   `AbstractDb`, `SearchCriteria`, service-contract and declarative-schema patterns, XSD shapes).
4. **Official Magento/Adobe developer documentation** — live-fetched *only when* a framework
   contract or best-practice is still genuinely uncertain after 1–3 (see "Live-doc fetch" below).

Unrelated local modules appear **nowhere** in this list.

## Prohibition

Do **not** read, `grep`, `find`, or "study" other modules under `app/code`, `vendor/*`, or Magento
core to infer conventions, entity shapes, naming, wiring, or "how it's usually done" for the code
being generated. Neighbouring modules may be deprecated, WIP, under debugging, or third-party —
they are not a source of truth for new code. "Let me look at a similar module" is banned.

## Allowed reads (the "directly related" exceptions)

Reading local code is permitted **only** here:

- **The target of the operation** — the module being augmented (`--mode=augment`), or the existing
  class/entity a surface attaches to (extension-point, webapi, graphql, adminhtml form/listing,
  breeze-module-adapt, docs-generate, test-generate). This *is* the feature under development.
- **A module the new code explicitly depends on** — named by the user, or declared via
  `etc/module.xml` `<sequence>` / composer `require`. Read **only the specific contract** the new
  code must satisfy (the `Api/` interface, the event name, the plugin target's method signature,
  the extension-attribute interface). Do not browse it for patterns.
- **Vendor-name detection** — immediate directory *names* under `app/code` only (unchanged; owned
  by `vendor-resolution.md`).

## Live-doc fetch protocol

- **Trigger:** after templates + references + baked knowledge, a *framework* contract or
  best-practice remains genuinely uncertain. Not a per-run step.
- **Allowlist (only these hosts):** `developer.adobe.com` (Adobe Commerce / Magento developer
  docs) and `devdocs.magento.com` (archived DevDocs). Never a code host or another extension's repo.
- **Purpose limit:** confirm a *framework fact* (interface signature, config/XSD convention,
  declarative-schema rule) — never "how another extension implemented X."
- **Graceful degradation:** if WebFetch is unavailable/offline/blocked, fall back to baked
  knowledge and proceed, noting "docs unreachable." Never fall back to scanning local modules.

## Report affirmation

A generator's final report states one line so the model self-audits:

> `Sources: templates + references[ + docs]; no unrelated modules scanned.`
