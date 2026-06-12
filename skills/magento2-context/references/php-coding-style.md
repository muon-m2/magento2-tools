# PHP Coding Style — PER-CS 3.0 Baseline, Magento 2 Precedence

Single source of truth for the coding style of **every PHP file generated or modified by a
`magento2-*` skill**. Consumed by the builder skills (module-create, graphql-create,
eav-attribute, data-migration, frontend-create, bug-fix) and by `magento2-module-review` as a
review lens.

## The Rule

1. **Baseline: PER Coding Style (PER-CS) 3.0.** Generated PHP follows the PHP-FIG PER Coding
   Style as its baseline formatting standard. (If the project's toolchain pins an earlier PER-CS
   revision, that revision applies — the precedence rule below is what matters, not the exact
   point release.)
2. **Magento 2 wins on conflict.** Where PER-CS conflicts with the **Magento 2 coding standard**
   (the `Magento2` PHPCS standard from `magento/magento-coding-standard`) or with a Magento
   framework requirement, the Magento 2 rule takes precedence. PER-CS never overrides Magento.
3. **Enforcement gate is unchanged.** `vendor/bin/phpcs --standard=Magento2` remains the single
   automated gate (it is what Magento CI and Marketplace EQP run). PER-CS is **guidance for
   generation and a review lens** — this rule does **not** add a second enforced PHPCS standard.
   Do not layer a PER-CS ruleset on top of `Magento2`; that produces conflicting output.

In short: **write PER-CS-clean code, then let the Magento 2 standard win wherever the two
disagree, and verify with `--standard=Magento2`.**

## Where the Two Agree (apply PER-CS freely)

These PER-CS conventions are compatible with `Magento2` and should always be applied:

- 4-space indentation; no tabs.
- One `namespace` per file; one blank line after it.
- Lowercase reserved keywords and lowercase short-form scalar type keywords (`int`, `bool`,
  `string`, `float`, `void`, `null`, `false`, `true`).
- One space around binary operators; no space inside parentheses/brackets.
- Visibility declared on every property, method, and class constant.
- Trailing comma on the last element of a multi-line array or multi-line argument/parameter list.
- Opening brace of a class/method on its own line; opening brace of a control structure on the
  same line.
- One blank line between methods; no more than one consecutive blank line.
- Soft line-length target of 120 columns.

## Where Magento 2 Takes Precedence (Magento wins)

Apply the Magento rule, not the PER-CS default, in these cases:

| Topic | PER-CS baseline | Magento 2 rule (apply this) |
|-------|-----------------|------------------------------|
| `declare(strict_types=1)` | Not mandated | **Required** — `<?php`, blank line, then `declare(strict_types=1);` on modern PHP/Magento targets. |
| PHPDoc content | Largely unspecified | Magento PHPDoc rules apply — FQCN with leading `\` in `@param`/`@return`/`@throws`, `@api` on `Api/` interfaces, etc. See `magento2-module-create/references/phpdoc-rules.md` and `magento2-module-review/references/phpdoc-code-style.md`. |
| Identifier naming | Style-only | Magento naming conventions win — class/method/variable/constant/XML-id/table/config-path naming per `magento2-context/references/naming.md`. |
| `final` classes/methods | Allowed | **Prohibited** — `Magento2.PHP.FinalImplementation` is an *error*: "Final keyword is prohibited in Magento; it decreases extensibility." Do not generate `final class`/`final function`, even on data patches or test classes. |
| Resource-model/collection init | n/a | Magento requires the `_construct()` method (leading underscore). PSR-12/PER flags it (`PSR2.Methods.MethodDeclaration`); keep it — Magento wins. |
| Static methods | Discouraged in app code | Magento warns (`Magento2.Functions.StaticFunction`), but `public static` PHPUnit data providers and `DataPatchInterface::getDependencies()` are required static — those warnings are acceptable. |
| Suppressions | Not addressed | `@SuppressWarnings` / `phpcs:disable` must be narrow and justified per the Magento standard; never used to silence a fixable `Magento2` sniff. |
| Anything a `Magento2` sniff flags | — | If `--standard=Magento2` reports it as an *error*, fix it the Magento way — the sniff is authoritative over any PER-CS preference. |

## Known Sniff Limitations (do not "fix" these)

Some `Magento2` warnings are sniff limitations, not real defects. Generators keep the modern,
correct code; projects that want a fully warning-clean CI exclude the specific sniff for the
affected paths in their `phpcs.xml`.

- **Intersection-typed properties** (`Foo&MockObject $x`, common in PHPUnit mocks): the
  `Magento2.Commenting.ClassPropertyPHPDocFormatting` sniff flags them *even with a correct
  `@var`* — it predates PHP 8.1 intersection types. Keep the intersection type; do **not** revert
  to an untyped property just to satisfy the sniff.
- **Complex array-shape `@param` types** (`array<int, array<string, mixed>>`,
  `array{a: int, b: string}`): the `Magento2.Annotation.MethodArguments` sniff cannot parse the
  spaces/braces and reports the parameter as "missing." Use a plain `array` type in the `@param`
  and put the shape in the description.

When PER-CS is silent and `Magento2` is also silent on a point, prefer the PER-CS convention for
consistency.

## For Reviewers

`magento2-module-review` reports PER-CS/style deviations at the severity already defined in
`phpdoc-code-style.md` (Low by default; escalate only when style breaks generated code, public
contracts, static analysis, or a release gate). A PER-CS deviation that the Magento 2 standard
explicitly requires is **not** a finding — Magento precedence is correct behaviour, not a defect.
