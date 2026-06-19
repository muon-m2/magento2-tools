# The Typed Message DTO

The message payload is a **typed Data Transfer Object**, not an array. This is the single
most important design rule for a robust queue surface.

## Three pieces

1. **Interface** — `Api/Data/{EntityName}Interface.php`, annotated `@api`, with field-name
   constants and typed getters/setters.
2. **Model** — `Model/{EntityName}.php`, implementing the interface with typed properties.
3. **Preference** — a `di.xml` `<preference for="…Interface" type="…Model"/>` so the
   framework instantiates the concrete model when it sees the interface.

`communication.xml` references the **interface** as the topic `request`. The framework
reads the interface's getters to build the serialization schema and uses the `di.xml`
preference to construct a concrete instance on the consumer side.

## Why not arrays

Publishing a bare array (`['order_id' => 5, 'status' => 'new']`) is tempting but wrong:

- **No schema.** The framework cannot validate the payload shape; a typo in a key is a
  silent runtime failure deep inside the consumer.
- **No typing.** The consumer's `process()` can't declare a typed parameter, so it loses
  IDE/static-analysis support and must defensively `isset()`-check every key.
- **Brittle evolution.** Adding a field means hunting every `$data['...']` access. With a
  DTO you add a typed getter/setter once.
- **PHPCS / review.** The Magento standard and `magento2-module-review` flag untyped array
  payloads as a Medium maintainability finding.

The framework explicitly supports typed message classes via the `request` attribute on the
topic — use it.

## Serialization

Magento's message-queue layer serializes the DTO to JSON on publish (via the topic's
`request` type) and reconstructs it on the consumer side. For this to round-trip cleanly:

- Every field exposed in the message must have a **typed getter** on the interface — the
  serializer reflects over getters (`getOrderId()` → `order_id`).
- A field with a setter but no getter will not survive the round trip.
- Use scalar / nullable-scalar types (`int`, `?int`, `string`, `?string`, `float`, `bool`)
  for queue payloads. Avoid nesting full entity objects; pass an **id** and re-load inside
  the handler, so the message stays small and the consumer always reads fresh state.

## Example shape

```php
interface {EntityName}Interface
{
    public const ENTITY_ID = 'entity_id';
    public const STATUS    = 'status';

    public function getEntityId(): ?int;
    public function setEntityId(int $entityId): void;

    public function getStatus(): string;
    public function setStatus(string $status): void;
}
```

```php
class {EntityName} implements {EntityName}Interface
{
    private ?int $entityId = null;
    private string $status = '';

    public function getEntityId(): ?int
    {
        return $this->entityId;
    }
    // … setters/getters …
}
```

```xml
<preference for="{Vendor}\{Module}\Api\Data\{EntityName}Interface"
            type="{Vendor}\{Module}\Model\{EntityName}"/>
```

## Publishing the DTO

Build the DTO (via its factory or a fluent setter chain), then publish it under the topic:

```php
$message = $this->messageFactory->create();
$message->setEntityId($id);
$this->publisher->publish(self::TOPIC, $message);
```

The publisher injects `Magento\Framework\MessageQueue\PublisherInterface`. The topic string
is a class constant (`TOPIC`) so the one literal lives in exactly one place on the PHP side
and is guaranteed identical to the XML topic.
