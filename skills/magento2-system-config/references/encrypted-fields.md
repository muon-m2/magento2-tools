# Encrypted Fields

Use this pattern for any config value that must be stored encrypted in the database
(API keys, passwords, tokens).

## system.xml declaration

```xml
<field id="api_key" translate="label" type="obscure" sortOrder="10"
       showInDefault="1" showInWebsite="1" showInStore="0">
    <label>API Key</label>
    <backend_model>Magento\Config\Model\Config\Backend\Encrypted</backend_model>
    <comment>Your API key from the service dashboard. Stored encrypted.</comment>
</field>
```

Two requirements:

1. `type="obscure"` — renders as `<input type="password">` in the admin UI; the browser
   does not auto-fill and the value is masked.
2. `backend_model="Magento\Config\Model\Config\Backend\Encrypted"` — encrypts the value
   on save and stores the cipher text in `core_config_data`. On load, the backend model
   does NOT decrypt automatically; your code must do it (see below).

## Storage

`core_config_data.value` holds the Magento-encrypted string (prefixed with the
encryption key version, e.g. `0:3:cipher…`). Reading it with `getValue()` returns the
cipher text, not the plaintext.

## Reading in the typed Config reader

Inject `\Magento\Framework\Encryption\EncryptorInterface` and call `decrypt()`:

```php
declare(strict_types=1);

namespace Acme\Module\Model;

use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Framework\Encryption\EncryptorInterface;
use Magento\Store\Model\ScopeInterface;

class Config
{
    private const XML_PATH_API_KEY = 'acme_module/api/api_key';

    public function __construct(
        private readonly ScopeConfigInterface $scopeConfig,
        private readonly EncryptorInterface $encryptor
    ) {}

    /** @param int|string|null $storeId */
    public function getApiKey($storeId = null): string
    {
        $encrypted = (string) $this->scopeConfig->getValue(
            self::XML_PATH_API_KEY,
            ScopeInterface::SCOPE_STORE,
            $storeId
        );
        return $encrypted !== '' ? $this->encryptor->decrypt($encrypted) : '';
    }
}
```

**Never return the cipher text.** Always decrypt before returning; always guard against
an empty string (no value saved yet).

## Setting encrypted values via CLI

```bash
# The CLI encrypts automatically when the backend model is Encrypted:
bin/magento config:set --lock-env acme_module/api/api_key "my-plaintext-key"
```

## Unit testing encrypted fields

In the typed reader unit test, mock both `ScopeConfigInterface` and `EncryptorInterface`:

```php
$this->scopeConfigMock
    ->method('getValue')
    ->with('acme_module/api/api_key', ScopeInterface::SCOPE_STORE, null)
    ->willReturn('0:3:encryptedvalue');

$this->encryptorMock
    ->method('decrypt')
    ->with('0:3:encryptedvalue')
    ->willReturn('my-plaintext-key');

self::assertSame('my-plaintext-key', $this->config->getApiKey());
```

## Security notes

- Never log the decrypted value.
- Never expose the decrypted value in a URL or HTML response.
- The encryption key is in `app/etc/env.php` under `crypt/key`. Rotate it with
  `bin/magento encryption:payment-data:update` (Adobe Commerce) or by re-encrypting
  manually (Open Source).
- On store transfer: export config via `bin/magento app:config:dump`, then re-enter
  secrets manually in the new environment.
