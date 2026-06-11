# Slow Query Patterns

## Reading the MySQL Slow Log

```bash
{ctx.runner} cat /var/log/mysql/slow.log
```

Or via `mysqldumpslow` if available:

```bash
{ctx.runner} mysqldumpslow -s t -t 20 /var/log/mysql/slow.log
```

Reports queries by total time, in descending order.

## Grouping by Signature

The parser replaces literal values with `?`:

```sql
SELECT * FROM catalog_product_entity WHERE entity_id = 12345 AND store_id = 1
-->
SELECT * FROM catalog_product_entity WHERE entity_id = ? AND store_id = ?
```

Group queries with the same signature; report:

- count
- total time
- average time
- max time
- sample full query

## Index Suggestions

For each slow query signature, inspect:

```sql
EXPLAIN <query>;
```

Common findings:

| Symptom                       | Recommendation                                          |
|-------------------------------|---------------------------------------------------------|
| `type: ALL` (full table scan) | Add index on the WHERE column(s)                        |
| `key: NULL`                   | Add index covering WHERE + ORDER BY                     |
| `Extra: Using temporary`      | Consider whether ORDER BY can use the same index        |
| `Extra: Using filesort`       | Index column ordering may be wrong                      |
| `rows: > 100000`              | Query likely needs a different shape, not just an index |

## Magento-Specific Slow Patterns

| Pattern                                     | Fix                                                   |
|---------------------------------------------|-------------------------------------------------------|
| `WHERE entity_id IN (1,2,3,...50K)`         | Chunk the IN list to ≤ 500                            |
| `LEFT JOIN catalog_product_index_*`         | Verify the right index table for store/customer group |
| `ORDER BY rand()`                           | Replace with deterministic ordering                   |
| `WHERE updated_at > NOW() - INTERVAL N DAY` | Add index on `updated_at`                             |
| EAV multi-attribute filter                  | Use flat tables or `catalog_product_index_*`          |

## Slow Query Finding Format

```json
{
  "id": "debug-2026-05-24-slow-001",
  "severity": "medium",
  "category": "slow_query",
  "title": "Slow query: catalog_product_entity full scan (4.2s)",
  "evidence": [
    { "file": "var/log/mysql/slow.log", "line": 1, "snippet": "SELECT ... FROM catalog_product_entity WHERE ..." }
  ],
  "recommendation": "Add an index on (store_id, status) — EXPLAIN shows full table scan.",
  "verification": "Re-run after index; EXPLAIN should show type=ref or type=range, key=new_index."
}
```

## Limitations

- Slow log requires `long_query_time` configuration; default is often 10s, which misses
  the 1-5s queries that matter.
- Slow log only captures queries; not in-PHP processing time.
- A query that's "fast" but called 10K times per request is invisible in slow log —
  use Blackfire for those.
