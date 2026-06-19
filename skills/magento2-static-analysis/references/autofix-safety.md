# Autofix Safety Reference

Classifies every static-analysis transform into SAFE (auto-apply in Phase 3) vs
REVIEW-REQUIRED (propose only — never auto-applied without per-rule approval).

## Classification Principle

A transform is **SAFE** when it is purely mechanical and cannot change observable
behaviour: whitespace, import ordering, formatting, or type annotations that the
compiler already enforces and that the tool can verify from the AST alone.

A transform is **REVIEW-REQUIRED** when it changes runtime semantics, removes code
paths, broadens or narrows type constraints, or touches public API signatures.

## phpcbf (Magento2 standard)

phpcbf auto-fixes the subset of PHPCS violations that have a mechanical fix. All
phpcbf transforms are classified **SAFE** — they are pure whitespace/formatting fixes
that PHPCS itself verifies as correct.

| Category | Examples | Safety |
|----------|---------|--------|
| Whitespace | Trailing spaces, blank lines, indentation | SAFE |
| Brace placement | Opening brace on same/next line | SAFE |
| Import ordering | `use` statement ordering | SAFE |
| Quote normalisation | Single ↔ double quote per sniff rule | SAFE |
| Line-ending | CRLF → LF | SAFE |
| PHPDoc formatting | Spacing, alignment | SAFE |

## php-cs-fixer

| Rule / Rule Set | Safety |
|-----------------|--------|
| `@PSR12` | SAFE |
| `no_unused_imports` | SAFE |
| `ordered_imports` | SAFE |
| `trailing_comma_in_multiline` | SAFE |
| `single_quote` | SAFE |
| `array_syntax` (`short`) | SAFE |
| `no_extra_blank_lines` | SAFE |
| `blank_line_before_statement` | SAFE |
| `phpdoc_trim`, `phpdoc_indent` | SAFE |
| `return_assignment` (splits compound return into variable) | REVIEW-REQUIRED |
| `combine_consecutive_issets` | REVIEW-REQUIRED |
| `no_useless_return` (removes `return;` at end) | REVIEW-REQUIRED — may affect mocking |
| `strict_comparison` (`==` → `===`) | REVIEW-REQUIRED — semantic change |
| `native_function_invocation` | REVIEW-REQUIRED — namespace impact |

**Auto-apply only the SAFE rules.** When a project `.php-cs-fixer.dist.php` is present,
respect it but log which REVIEW-REQUIRED rules it activates and present them for human
confirmation before applying.

## rector Sets

| Set / Rule | Safety |
|------------|--------|
| `Php74.Php74 TypeDeclarationRector` — add typehints derived from PHPDoc | SAFE when PHPDoc types are verified via phpstan level ≥ 5 on the same codebase |
| `CodingStyle.ReturnArrayClassMethodToYieldRector` | REVIEW-REQUIRED — changes generator semantics |
| `DeadCode.RemoveUnusedVariableRector` | SAFE for local variables with no side effects |
| `DeadCode.RemoveDeadInstanceOfRector` | REVIEW-REQUIRED — may affect mocking |
| `DeadCode.RemoveUnusedPrivateMethodRector` | REVIEW-REQUIRED — reflection callers |
| `TypeDeclaration.AddVoidReturnTypeWhereNoReturnRector` | SAFE |
| `TypeDeclaration.ReturnTypeFromReturnNewRector` | SAFE |
| `TypeDeclaration.ParamTypeFromStrictTypedPropertyRector` | SAFE |
| `Php80.UnionTypesRector` (PHP 8.0 union types) | SAFE when the project targets PHP ≥ 8.0 |
| `Php81.ReadOnlyPropertyRector` | REVIEW-REQUIRED — changes property semantics |
| `Php82.ReadonlyClassRector` | REVIEW-REQUIRED — breaks extensibility (Magento prohibits final/readonly on extensible classes) |
| `Magento2.` ruleset (if installed) | SAFE for import/preference rules; REVIEW-REQUIRED for others |

### Rector — Proposal-Only Policy

**No rector transform is auto-applied by this skill.** Rector runs exclusively in
`--dry-run` mode during Phase 2 (detection). All rector output is proposal-only;
the developer reviews the proposed transforms and applies them manually. This policy
applies even to transforms previously classified SAFE — the risk/review overhead of
running rector in write mode is not worth automating in a CI gate context.

For reference, transforms that are lower-risk (and thus reasonable to apply manually
without deep review) include:
- `DeadCode.RemoveUnusedVariableRector`
- `TypeDeclaration.AddVoidReturnTypeWhereNoReturnRector`
- `TypeDeclaration.ReturnTypeFromReturnNewRector`
- `TypeDeclaration.ParamTypeFromStrictTypedPropertyRector`
- `Php80.UnionTypesRector` (only when `{ctx.php_version}` ≥ 8.0)

Transforms that require careful manual review before applying:
- Any `DeadCode` rule that removes methods, properties, or class members
- Any `Php81`/`Php82` rule (readonly — breaks Magento extensibility model)
- Any rule that changes a public API signature

## Exclusions — Never Touch

Regardless of classification:

- `vendor/` — third-party code, must never be modified
- `generated/` — auto-generated DI / proxy classes
- `var/` — runtime state
- `pub/static/` — compiled static assets

All fixer invocations must pass `--ignore=*/vendor/*,*/generated/*,*/var/*,*/pub/static/*`
(or the tool's equivalent exclude flag).
