# Config Reader Pattern

The **typed Config reader** (`Model/Config.php`) is the single place in a module that
knows config paths and scope constants. All business code receives the reader via
constructor injection and calls its typed getters; no business class imports
`ScopeConfigInterface` directly.

## Why a typed reader?

- Config path strings (e.g. `"acme_checkout/general/enable_feature"`) scattered across
  service classes are error-prone and hard to refactor.
- Type-casted getters (string, int, bool, array) prevent repeated cast boilerplate.
- The reader is the single place that documents every config path the module owns.

## Class structure

```php
declare(strict_types=1);

namespace Acme\Checkout\Model;

use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;

class Config
{
    private const XML_PATH_ENABLE = 'acme_checkout/general/enable';
    private const XML_PATH_API_KEY = 'acme_checkout/api/api_key';

    public function __construct(
        private readonly ScopeConfigInterface $scopeConfig
    ) {}

    /** @param int|string|null $storeId */
    public function isEnabled($storeId = null): bool
    {
        return $this->scopeConfig->isSetFlag(
            self::XML_PATH_ENABLE,
            ScopeInterface::SCOPE_STORE,
            $storeId
        );
    }

    /** @param int|string|null $storeId */
    public function getApiKey($storeId = null): string
    {
        return (string) $this->scopeConfig->getValue(
            self::XML_PATH_API_KEY,
            ScopeInterface::SCOPE_STORE,
            $storeId
        );
    }
}
```

## ScopeConfigInterface methods

| Method | Returns | Use when |
|--------|---------|----------|
| `getValue($path, $scopeType, $scopeCode)` | `mixed` | String/int/float/array values |
| `isSetFlag($path, $scopeType, $scopeCode)` | `bool` | Boolean toggle fields (select + Yesno source) |

Always pass `\Magento\Store\Model\ScopeInterface::SCOPE_STORE` as `$scopeType` (the
constant value is `"store"`). This resolves the narrowest override automatically.

## Type casting

| Config type | PHP type | Cast |
|-------------|----------|------|
| `text` | `string` | `(string)` |
| `textarea` | `string` | `(string)` |
| `select` (Yesno) | `bool` | Use `isSetFlag()` |
| `select` (other) | `string` | `(string)` |
| `multiselect` | `string[]` | `explode(',', (string) $value)` — filter empty |
| `obscure` | `string` | Decrypt via `encryptor->decrypt((string) $value)` |

## Store-aware getter signature

All public getters accept an optional `$storeId` parameter so they work in both frontend
(pass the current store id) and backend/CLI (pass `null`, falls back through
website → default):

```php
/** @param int|string|null $storeId */
public function getSomeValue($storeId = null): string
{
    return (string) $this->scopeConfig->getValue(
        self::XML_PATH_SOME_VALUE,
        ScopeInterface::SCOPE_STORE,
        $storeId
    );
}
```

## Encrypted fields

For `type="obscure"` fields with the Encrypted backend model, the stored value is
encrypted. The typed reader must decrypt it before returning:

```php
use Magento\Framework\Encryption\EncryptorInterface;

public function __construct(
    private readonly ScopeConfigInterface $scopeConfig,
    private readonly EncryptorInterface $encryptor
) {}

public function getApiKey($storeId = null): string
{
    $value = (string) $this->scopeConfig->getValue(
        self::XML_PATH_API_KEY,
        ScopeInterface::SCOPE_STORE,
        $storeId
    );
    return $value !== '' ? $this->encryptor->decrypt($value) : '';
}
```

See `encrypted-fields.md` for more detail.

## DI registration

No `di.xml` entry is needed for a plain class. Business code declares
`\Acme\Checkout\Model\Config $config` as a constructor parameter and Magento's
object manager injects it automatically.

## Unit test

The test mocks `ScopeConfigInterface`, sets expectations on `getValue`/`isSetFlag` calls
with the exact path and scope, and asserts the returned/cast value. No `markTestIncomplete`.
See `${CLAUDE_SKILL_DIR}/templates/test-config-reader-unit.php`.
