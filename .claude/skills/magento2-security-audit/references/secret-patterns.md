# Secret Patterns

Regex patterns for detecting hardcoded secrets when `gitleaks` / `trufflehog` are
unavailable.

## Pattern Pack

### AWS

| Type | Pattern |
|------|---------|
| Access key ID | `AKIA[0-9A-Z]{16}` |
| Secret access key | `aws_secret_access_key.*[=:]\s*['"][A-Za-z0-9/+]{40}['"]` |
| Session token | `aws_session_token.*[=:]\s*['"][A-Za-z0-9/+=]{100,}['"]` |

### Stripe

| Type | Pattern |
|------|---------|
| Live publishable | `pk_live_[0-9a-zA-Z]{24,99}` |
| Live secret | `sk_live_[0-9a-zA-Z]{24,99}` |
| Test secret | `sk_test_[0-9a-zA-Z]{24,99}` |
| Webhook secret | `whsec_[a-zA-Z0-9]{32,99}` |

### GitHub

| Type | Pattern |
|------|---------|
| Personal access token | `ghp_[A-Za-z0-9]{36}` |
| Fine-grained PAT | `github_pat_[A-Za-z0-9_]{82}` |
| Server-to-server | `ghs_[A-Za-z0-9]{36}` |

### Google

| Type | Pattern |
|------|---------|
| API key | `AIza[0-9A-Za-z\-_]{35}` |
| OAuth | `[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com` |

### Generic

| Type | Pattern |
|------|---------|
| JWT | `ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` |
| Bearer token in source | `Bearer\s+[A-Za-z0-9._-]{32,}` |
| Hardcoded password define | `define\(['"](?:DB_PASSWORD|PASSWORD|SECRET)['"]\s*,\s*['"][^'"]{6,}['"]\)` |
| RSA private key block | `-----BEGIN (?:RSA )?PRIVATE KEY-----` |
| SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----` |

### Magento-Specific

| Type | Pattern |
|------|---------|
| Encryption key in env.php | `'crypt'.*'key'\s*=>\s*'[a-f0-9]{32,}'` |
| Marketplace MAGE token | `[a-f0-9]{32}` near `repo.magento.com` |
| Admin password reset token in URL | `key/[a-f0-9]{64}/` in logs/configs |

## Scan Scope

Default: `{ctx.magento_root}/app/code/{Vendor}/`, `src/app/etc/env.php` (in git history only),
`src/composer.json`, `src/composer.lock`, `.env.example`, every `etc/config.xml`.

Exclude: `vendor/`, `pub/static/`, `var/`, `generated/`, `node_modules/`.

## False-Positive Handling

- `XXXXXXX...` / `your_key_here` / `replace-me` style placeholders → skip.
- Test fixtures with explicit `// test-secret` comment → skip.
- Keys in `.env.example` or `.env.dist` → flag as Low (template files should not contain
  real secrets, but they sometimes do).

## Severity Mapping

| Pattern | Default severity |
|---------|------------------|
| Live secret key (`sk_live_`, `AKIA...` with paired secret) | Critical |
| Live API key (`AIza...`, `ghp_...`) | High |
| Test key | Low |
| Private key block | Critical |
| Encryption key in env.php | Critical (if env.php is committed) |
| Hardcoded password in source | High |
| Bearer token in source | High |
| JWT | Medium (may be a test fixture; verify) |

## Output Format

```json
{
  "id": "security-audit-2026-05-24-secret-001",
  "severity": "critical",
  "category": "secret",
  "title": "AWS access key ID found in source",
  "evidence": [
    { "file": "src/app/code/Acme/Aws/Service/Client.php", "line": 23 }
  ],
  "recommendation": "Rotate the key immediately. Move the secret to environment variables or Magento's encrypted config. Remove from git history (BFG / git-filter-repo).",
  "verification": "Re-run scan after rotation."
}
```
