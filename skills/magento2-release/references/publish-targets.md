# Publish Targets

## Packagist

For modules published to Packagist:

1. Push tag to GitHub.
2. Webhook from GitHub to Packagist auto-detects the new tag and publishes it.
3. Within a few minutes, `composer require {vendor}/{package}:1.4.0` works.

Verify webhook configuration in:
```
https://packagist.org/packages/{vendor}/{package}
```

If the webhook isn't configured, manually click "Update" on the Packagist package page.

## Private Repository (Satis / Private Packagist)

```bash
composer config repositories.private composer https://composer.example.com
composer publish
```

Or, for Satis:

```bash
satis build satis.json /var/www/composer
```

Specifics depend on the registry. The skill detects from `composer.json`:

```json
"repositories": [
    {"type": "composer", "url": "https://composer.example.com"}
]
```

And prompts the user for the publish command if not standard.

## GitHub Packages

```bash
gh release upload {tag} {Module}-{Version}.zip
```

Or, for Composer-style:

```bash
composer config repositories.github composer https://composer.github.com/{owner}
COMPOSER_AUTH='{"github-oauth": {"github.com": "..."}}' composer require {vendor}/{package}
```

## No-Publish Mode

If the module is internal and never published externally, `--no-publish` skips Phase 7.
The release still tags and updates CHANGELOG; the tag itself is the artefact.

## Verification

After publishing, the report includes a verification command:

```bash
composer require {vendor}/{package}:{version}
```

The user runs this in a clean environment to confirm the new version resolves.

## Marketplace (Adobe Commerce Marketplace)

Marketplace publishing is a separate, manual process via the Marketplace developer
portal. This skill does NOT push to Marketplace — but it does prepare the artefact:

```bash
zip -r {Module}-{Version}.zip {module-folder} -x "Test/*"
```

Save the zip alongside the release notes. The user uploads to Marketplace manually.
