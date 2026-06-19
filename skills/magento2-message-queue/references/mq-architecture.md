# Message-Queue Architecture

A Magento 2 async message queue is wired across **five** declaration files plus the PHP
publisher/consumer. They only work if the names line up. This is the whole point of the
skill — get the join keys right.

## The five XML files and how they chain

```
communication.xml   topic  ──────────────► defines the topic name + its typed request DTO
        │  (TopicName)
        ▼
queue_publisher.xml publisher ────────────► topic → connection + exchange (where to PUBLISH)
        │  (TopicName, ConnectionName, ExchangeName)
        ▼
queue_topology.xml  exchange + binding ────► exchange routes TopicName → a destination queue
        │  (ExchangeName, TopicName, QueueName, ConnectionName)
        ▼
        QueueName  ◄───────────────────────  the physical queue messages land in
        ▲
        │
queue_consumer.xml  consumer ──────────────► consumer reads QueueName, calls the handler
           (ConsumerName, QueueName, ConnectionName, handler FQCN::process)
```

The join keys, expressed as the canonical tokens:

| Token | communication | topology | publisher | consumer | publisher.php |
|-------|:------------:|:--------:|:---------:|:--------:|:-------------:|
| `{TopicName}` | ✓ (`topic name`) | ✓ (`binding topic`) | ✓ (`publisher topic`) | — | ✓ (`TOPIC` const) |
| `{ExchangeName}` | — | ✓ (`exchange name`) | ✓ (`connection exchange`) | — | — |
| `{QueueName}` | — | ✓ (`binding destination`) | — | ✓ (`consumer queue`) | — |
| `{ConnectionName}` | — | ✓ (`exchange connection`) | ✓ (`connection name`) | ✓ (`consumer connection`) | — |
| `{ConsumerName}` | — | — | — | ✓ (`consumer name` + handler) | — |

If `{TopicName}` in `communication.xml` differs by even one character from the topic in
`queue_publisher.xml`, `bin/magento queue:consumers:start` will silently do nothing —
messages are published to an exchange that has no binding for that topic.

## What each file declares

### communication.xml — the contract

Declares the topic and the **typed request** message class. This is what makes the payload
a DTO rather than an array:

```xml
<topic name="{TopicName}" request="{Vendor}\{Module}\Api\Data\{EntityName}Interface"/>
```

`request` is the FQCN of the message interface. The framework uses it to (de)serialize the
payload on publish and to type-check the consumer's argument. Schema URN:
`urn:magento:framework:MessageQueue/etc/communication.xsd`.

### queue_publisher.xml — where to publish

Maps the topic to the connection + exchange the publisher writes to:

```xml
<publisher topic="{TopicName}">
    <connection name="{ConnectionName}" exchange="{ExchangeName}"/>
</publisher>
```

Schema URN: `urn:magento:framework-message-queue:etc/publisher.xsd`.

### queue_topology.xml — routing

Declares the exchange and the binding that routes a topic to a destination queue:

```xml
<exchange name="{ExchangeName}" type="topic" connection="{ConnectionName}">
    <binding id="{Vendor}{Module}{EntityName}Binding" topic="{TopicName}"
             destinationType="queue" destination="{QueueName}"/>
</exchange>
```

`type="topic"` enables topic-pattern routing. Schema URN:
`urn:magento:framework-message-queue:etc/topology.xsd`.

### queue_consumer.xml — the worker

Maps a named consumer to the queue it drains and the handler it calls per message:

```xml
<consumer name="{ConsumerName}" queue="{QueueName}" connection="{ConnectionName}"
          handler="{Vendor}\{Module}\Model\Consumer\{ConsumerName}::process"/>
```

Schema URN: `urn:magento:framework-message-queue:etc/consumer.xsd`.

### di.xml — bind the DTO

A `<preference>` maps the message interface to its concrete model so the framework can
instantiate the typed payload:

```xml
<preference for="{Vendor}\{Module}\Api\Data\{EntityName}Interface"
            type="{Vendor}\{Module}\Model\{EntityName}"/>
```

## `db` vs `amqp` connection

| | `connection="db"` | `connection="amqp"` |
|---|---|---|
| Broker | None — uses MySQL tables (`queue`, `queue_message`, …) | RabbitMQ (configured in `app/etc/env.php`) |
| Setup | Works out of the box | Requires a running, reachable broker |
| Exchange | Implicit `magento` exchange | Your declared exchange |
| Throughput | Adequate for low/medium volume | High volume, true async |
| Default | **Yes** — the safe default | Only when AMQP is confirmed |

Pick `db` unless the project team confirms a RabbitMQ broker is provisioned and running.
Switching later is a one-line change to the `connection` attribute in the publisher,
topology, and consumer XML — keep the value consistent across all three.

For the `db` connection the exchange is conventionally `magento`. For AMQP, declare an
explicit exchange name. Either way the `{ExchangeName}` used in `queue_publisher.xml` must
match the one declared in `queue_topology.xml`.
