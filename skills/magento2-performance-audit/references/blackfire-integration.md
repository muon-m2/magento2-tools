# Blackfire / Tideways Integration

When a Blackfire or Tideways profile is available, surface the top hotspots in the
performance audit report.

## Detecting Blackfire Configuration

Probe in order:
1. `~/.blackfire.ini`
2. `BLACKFIRE_CLIENT_ID` env var
3. `BLACKFIRE_SERVER_TOKEN` in `.env`

If none present, skip Phase 4.

## Profile Generation Workflow

The skill does not run profiling itself. It asks the user to:

```
blackfire curl https://your-site.example.com/checkout/cart
```

And paste the resulting profile URL.

The skill fetches the profile JSON via Blackfire's API and surfaces the top 10 hotspots
by exclusive wall-clock time.

## Parsing the Profile

```python
import json, requests
profile = requests.get(blackfire_api_url, headers={'Authorization': f'Bearer {token}'}).json()
top = sorted(profile['nodes'], key=lambda n: n['ewt'], reverse=True)[:10]
for node in top:
    print(f"{node['symbol']}: {node['ewt']}ms ({node['callCount']} calls)")
```

## Hotspot Categorization

| Hotspot type | Recommendation |
|--------------|----------------|
| `Magento\Catalog\Model\Product\Collection::load` | Filter the collection; reduce attribute select |
| `Magento\Eav\Model\Entity\Attribute\Backend\*` | Backend model may be doing per-row I/O |
| `Magento\Catalog\Block\Product\AbstractProduct::*` | Block work in render path; consider ViewModel |
| `*ResourceModel*` | DB query inefficiency; suggest index check |
| External HTTP | Move to async; use a queue |

## Tideways

Tideways is an alternative. Probe `~/.tideways.ini`. The profile JSON has a different
shape; use the Tideways docs to extract per-function exclusive time.

## Output Format

Each hotspot becomes a finding:

```json
{
  "id": "perf-audit-2026-05-24-bf-001",
  "severity": "high",
  "category": "n_plus_one",
  "subcategory": "blackfire-hotspot",
  "title": "Magento\\Catalog\\Model\\Product\\Collection::load consumed 1240ms (35% of request)",
  "evidence": [
    { "file": "Blackfire profile", "line": 1, "snippet": "Profile URL: https://blackfire.io/profile/..." }
  ],
  "recommendation": "Profile reveals catalog collection load is the dominant cost. Add field-level filter; reduce attribute select; consider PageBuilder caching.",
  "verification": "Re-profile after the change; ewt should drop."
}
```

## Limitations

- Blackfire profiles require live HTTP; this skill never triggers them.
- Profile is a snapshot of one request; not representative of all requests.
- The skill recommends a profile for a "slow" URL; the user picks which URL.
