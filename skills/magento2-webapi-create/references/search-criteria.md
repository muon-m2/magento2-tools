# SearchCriteria & getList

`getList(SearchCriteriaInterface $searchCriteria)` is the standard list endpoint. The Web API
builds the `SearchCriteria` from the request query string — you do not parse it yourself.

## Request shape (REST)

```
GET /V1/{vendor}/{route}?searchCriteria[filter_groups][0][filters][0][field]=name
    &searchCriteria[filter_groups][0][filters][0][value]=Acme%25
    &searchCriteria[filter_groups][0][filters][0][condition_type]=like
    &searchCriteria[sortOrders][0][field]=created_at
    &searchCriteria[sortOrders][0][direction]=DESC
    &searchCriteria[pageSize]=20
    &searchCriteria[currentPage]=1
```

- **filter_groups** are AND-ed together; **filters** within a group are OR-ed.
- **condition_type**: `eq`, `neq`, `like`, `in`, `nin`, `gt`, `lt`, `gteq`, `lteq`, `from`, `to`, `null`, `notnull`.
- Omitting `searchCriteria` entirely returns everything (respecting any default page size) — fine
  for small datasets, dangerous for large ones.

## Implementation

The repository delegates the whole translation to `CollectionProcessorInterface`:

```php
$collection = $this->collectionFactory->create();
$this->collectionProcessor->process($searchCriteria, $collection);

$searchResults = $this->searchResultsFactory->create();
$searchResults->setSearchCriteria($searchCriteria);
$searchResults->setItems($collection->getItems());
$searchResults->setTotalCount($collection->getSize());   // total BEFORE pagination
return $searchResults;
```

- `setTotalCount($collection->getSize())` returns the **unpaginated** total, which is what the
  client needs for pagination. `count($items)` would only report the current page.
- `setSearchCriteria(...)` echoes the criteria back in the response envelope.

## CollectionProcessor

Magento binds a default `CollectionProcessor` (filters + sorting + pagination). Declare a virtual
type only when you need entity-specific handling — e.g. a custom `FilterProcessor` that maps an API
field name to a joined column, or a full-text filter:

```xml
<virtualType name="{Vendor}\{ModuleName}\Model\Api\SearchCriteria\CollectionProcessor"
             type="Magento\Framework\Api\SearchCriteria\CollectionProcessor">
    <arguments>
        <argument name="processors" xsi:type="array">
            <item name="filters" xsi:type="object">...custom FilterProcessor...</item>
        </argument>
    </arguments>
</virtualType>
```

Then inject that virtual type into the repository in `di.xml`. Keep the default unless a real need
appears (YAGNI).

## Performance

- Always paginate large collections — never let `getList` full-load a big table.
- If the client only needs a few fields, consider `addFieldToSelect` on the collection rather than
  hydrating the whole row.
- Watch for N+1 when DTOs lazy-load related data per item; resolve it with a join or a batched
  secondary query, not a per-item load.
