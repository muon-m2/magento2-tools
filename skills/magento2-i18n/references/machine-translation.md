# Machine Translation

For new locales or missing rows, optional machine translation populates the translation
column. Off by default; opt in with `--machine-translate`.

## Supported Providers

| Provider                 | Env var          | Quality                            |
|--------------------------|------------------|------------------------------------|
| DeepL                    | `DEEPL_API_KEY`  | Best for European languages        |
| Google Cloud Translation | `GOOGLE_API_KEY` | Wide language coverage             |
| OpenAI                   | `OPENAI_API_KEY` | Best for context-aware translation |
| Local LLM (Ollama)       | `OLLAMA_HOST`    | Privacy; quality varies            |

The skill detects the first available provider via env vars; user can override with
`--provider=deepl|google|openai|ollama`.

## Quality Caveat

Machine translations are STARTING POINTS, not final. Magento storefront copy is
customer-facing — a human translator must review before production. The skill marks
machine-translated rows with a sentinel:

```csv
"Hello %1","Bonjour %1"                                                # human-translated
"Welcome to checkout","Bienvenue à la caisse  # [MT: deepl, 2026-05-24]"  # machine
```

When the user later reviews, they remove the `# [MT: ...]` comment.

## Placeholder Preservation

The translation prompt explicitly tells the provider: "Preserve `%1`, `%2` placeholders
exactly." Providers occasionally drop or rewrite them; the skill re-checks placeholder
counts post-translation and re-tries on mismatch (max 3 attempts).

## Cost Management

For a module with 500 phrases × 20 locales:

- DeepL Pro: $25 / 1M characters → ~$1 per locale
- Google: $20 / 1M characters → ~$1 per locale
- OpenAI gpt-4o-mini: ~$5 per locale

The skill estimates cost in Phase 1 if `--machine-translate` is set, and confirms
before calling the API.

## Rate Limiting

Translate in batches of ~50 strings per API call. The skill paces requests to avoid
hitting rate limits.

## Cache

Translation calls are cached at
`.claude/.cache/machine-translation-{provider}-{locale}.json` keyed by source-phrase
hash. Re-running for the same source-phrase reuses cache.

## Disabling

Pass `--no-machine-translate` (or omit `--machine-translate`) to skip. The CSV will
have empty translations for new phrases.

## Privacy

Translation APIs see the source phrases. For modules with proprietary terminology, use
Ollama or a private endpoint. The skill never sends customer data — only the `__()` /
`<label>` string literals.
