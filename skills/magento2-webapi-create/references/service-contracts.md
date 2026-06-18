# Service Contracts

The service contract is the public, stable surface of a module. For the Web API it is also the
*schema source*: Magento reflects the `@api` interface and its DTO to build the REST/SOAP schema.

## The three pieces

| Piece | Lives in | Role |
|-------|----------|------|
| Repository interface | `Api/{Entity}RepositoryInterface.php` | The operations (`save`, `getById`, `getList`, `delete`, `deleteById`, custom actions). Routes in `webapi.xml` bind to its methods. |
| Data interface (DTO) | `Api/Data/{Entity}Interface.php` | The entity shape — typed getters/setters become JSON fields. |
| Search-results interface | `Api/Data/{Entity}SearchResultsInterface.php` | The `getList` envelope: `items` + `search_criteria` + `total_count`. |

## Rules

- **Interfaces under `Api/`, implementations under `Model/`.** The interface is `@api`; the
  implementation is wired via a `<preference>` in `etc/di.xml`. Routes reference the *interface*,
  never the concrete class — that is what keeps the contract swappable.
- **Mark `@api`.** It signals backward-compatibility intent and is required for the Web API to
  expose the interface. Removing or narrowing a published method is a breaking change.
- **Type everything.** The Web API builds its schema from parameter and return type declarations
  and DocBlocks. `array` returns need a `@return Type[]` DocBlock so the element type is known.
- **DTO returns the interface, not the model.** Methods return `\{Vendor}\{ModuleName}\Api\Data\{Entity}Interface`,
  not `\{Vendor}\{ModuleName}\Model\{Entity}`. The `di.xml` preference maps the interface to the model.
- **Scalars and DTOs only.** Web API method parameters/returns must be scalars, `Api/Data`
  interfaces, or arrays of those — not collections, not framework objects.

## Why not expose the model directly

The model carries persistence concerns (resource model, event prefixes, magic getters) that must
not become part of the public contract. The DTO interface is the agreed shape; the model is free
to change behind it. This is what lets `getList` return `{Entity}Interface[]` while the underlying
collection is an ORM detail.

## Custom (non-CRUD) actions

Add a method to the repository interface (or a dedicated `Api/{Entity}ManagementInterface` when the
action is not really a repository concern), implement it, and add a matching `<route>`. Keep
business logic in a domain service injected into the implementation — the repository should stay a
thin persistence/orchestration layer. See the `activate` example in the templates.
