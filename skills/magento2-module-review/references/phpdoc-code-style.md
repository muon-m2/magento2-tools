# PHPDoc, Code Style, And Design Principles

Use this reference during the maintainability and standards pass.

## Code Style

- Baseline is **PER-CS 3.0**; the **Magento 2 coding standard takes precedence on any conflict**
  (it is the `--standard=Magento2` enforcement gate). See
  `magento2-context/references/php-coding-style.md` for the precedence rule and the known
  Magento-wins cases. A PER-CS deviation that the Magento 2 standard explicitly requires (e.g.
  `declare(strict_types=1)`, FQCN PHPDoc tags) is correct, not a finding.
- Use `declare(strict_types=1);` consistently when the module targets modern PHP/Magento versions that support it.
- Keep imports explicit and remove unused imports.
- Use fully qualified names intentionally; avoid noisy inline FQCNs when an import improves readability.
- Name classes, methods, variables, constants, XML IDs, table names, and config paths consistently with Magento
  conventions.
- Keep comments sparse and useful.

## PHPDoc Requirements

- Method and function PHPDoc must meet Magento 2 coding-standard formatting requirements.
- `@param`, `@return`, and `@throws` tags must use full class names with fully qualified namespaces for class/interface
  types.
- Do not use shortened imported class names in PHPDoc tags when a fully qualified class name is required.
- Public APIs and service contracts document parameters, returns, exceptions, side effects, and stability expectations.
- `@api`, `@internal`, `@deprecated`, `@see`, `@throws`, `@var`, and suppression annotations must be deliberate and
  accurate.
- Suppressions such as `@SuppressWarnings` or `phpcs:disable` must be narrow, justified, and not used to hide avoidable
  issues.
- Interface and implementation signatures must match their documented contracts.

## PHPDoc Brevity

- PHPDoc descriptions and inline comments must be as short as possible while preserving context.
- Skip PHPDoc descriptions or inline comments when purpose is already obvious from names, type declarations, method
  signatures, or nearby code.
- Prefer concise contract-focused PHPDoc over narrative explanations.
- Do not repeat obvious implementation details.
- Add comments only for non-obvious Magento framework behavior, intentional deviations, security decisions, or tricky
  lifecycle concerns.

## Design Principles

Apply these principles as concrete pass/fail criteria. Each entry includes a violation example and the correct Magento
pattern.

### Single Responsibility (SRP)

Each class has one reason to change. Raise a finding when responsibilities are mixed.

| Violation                                                                                  | Correct pattern                                                                                  |
|--------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Controller calls a repository, formats a response, and sends an email in one action method | Controller calls a service; service orchestrates repository + email sender                       |
| Block fetches product collection, applies business discount rules, and formats currency    | ViewModel fetches collection; separate helper/service handles discount logic; block formats only |
| Data patch runs DB inserts and dispatches events and sends HTTP requests                   | Patch runs DB inserts only; event observer or cron handles downstream side effects               |

### Open/Closed — Extension Without Modification

Prefer extension points over rewrites.

| Violation                                                                       | Correct pattern                                                                                      |
|---------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Class preference (`<preference>`) rewrites a Magento core class to add a method | Plugin (`<plugin>`) intercepts the specific method; no preference needed                             |
| Layout override copies and modifies a core `.xml` file entirely                 | Layout extension adds `<referenceBlock>` / `<referenceContainer>` to extend only the changed element |
| Observer modifies behavior by checking `instanceof` on the event object         | Dedicated event with a typed data object; observer declared only for that event                      |

### Dependency Inversion

Depend on abstractions; inject concrete infrastructure only where the framework makes it practical.

| Violation                                                                                   | Correct pattern                                                                                          |
|---------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| Service class type-hints `\Magento\Catalog\Model\ResourceModel\Product\Collection` directly | Type-hint `\Magento\Catalog\Model\ResourceModel\Product\CollectionFactory` or use a repository interface |
| Domain service injects `\Magento\Framework\HTTP\Client\Curl` for external calls             | Inject an interface or adapter; swap implementation via `di.xml` for testing                             |
| Constructor injects a concrete `Session` class, forcing full session bootstrap              | Declare `Session` in constructor but configure `Proxy` in `di.xml` for deferred initialization           |

### DRY — Centralize When Duplication Creates Risk

Accept small local duplication when abstraction would obscure framework intent. Centralize when the same logic must stay
in sync.

**Threshold heuristic:** centralise when (a) the same non-trivial logic appears in **3 or more files**, OR (b) the
logic involves a security decision (ACL check, input escaping, credential handling), OR (c) a change to the logic
would require editing more than two files to stay correct. Two identical lines in adjacent methods is not a finding.

| Duplication that warrants centralizing                                                 | Duplication that is acceptable                                     |
|----------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| Same ACL resource string repeated in three admin controllers                           | Same `__('Save')` label in two unrelated templates                 |
| Same date-formatting logic in a block, a REST response builder, and a GraphQL resolver | Identical two-line null-guard repeated in adjacent private methods |
| Same raw SQL query in both a resource model and a cron class                           | Trivial array-filter in two separate data patches                  |

### KISS — Prefer Native Patterns

| Over-engineering                                                                     | Simpler Magento-native equivalent                                                        |
|--------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| Custom event dispatcher service wrapping `\Magento\Framework\Event\ManagerInterface` | Inject `EventManagerInterface` directly; dispatch with `$this->eventManager->dispatch()` |
| Generic repository abstraction over Magento's own `SearchCriteriaInterface` pattern  | Implement `\Magento\Framework\Api\SearchCriteriaInterface` directly                      |
| Reflection-based config reader to avoid DI                                           | `\Magento\Framework\App\Config\ScopeConfigInterface` with a typed config model class     |

## Finding Guidance

- Report code style and PHPDoc issues as Low unless they break generated code, public contracts, static analysis, or
  release gates.
- Escalate to Medium when style or documentation problems create likely defects, unclear API contracts, or persistent
  maintenance risk.
- Do not create findings for personal preference alone.

