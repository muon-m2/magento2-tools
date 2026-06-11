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

## Private Composer Registry

There is **no** `composer publish` command — Composer has no native "publish" verb.
A private package is made available by exposing a Composer repository that the consumer's
`composer.json` points at. Three real workflows:

### (a) Private Packagist

Private Packagist (the hosted commercial product) mirrors your VCS. You don't push a
package to it directly — you push a git tag, and the registry pulls the new tag:

1. Connect the git repository once in the Private Packagist dashboard.
2. Push the release tag (Phase 5).
3. Private Packagist detects the new tag (via webhook, or on its sync schedule) and
   exposes `{vendor}/{package}:{version}`.

Consumers add the org's private repository URL:

```bash
composer config repositories.private composer https://repo.packagist.com/{org}/
```

### (b) Satis

Satis generates a **static** Composer repository from tagged VCS sources. After pushing
the tag, regenerate the static repo:

```bash
satis build satis.json /var/www/composer
```

`satis.json` lists the VCS repositories to index; the output directory is served as a
static Composer repo. Consumers point at it:

```json
"repositories": [
    {"type": "composer", "url": "https://composer.example.com"}
]
```

### (c) Plain VCS repository entry

No registry at all — the consumer references the git repository directly and Composer
resolves tags from it:

```json
"repositories": [
    {"type": "vcs", "url": "https://github.com/{owner}/{repo}.git"}
]
```

Then `composer require {vendor}/{package}:{version}` resolves against the pushed tag.

The skill detects the repository type from the consuming project's `composer.json` and,
for Private Packagist / Satis, the only action it performs is pushing the tag — the
registry side is configured out of band.

## GitHub as a Composer source

GitHub Packages does **not** support Composer/PHP packages (only npm, NuGet, RubyGems,
Maven, Gradle, Docker/Container, and Apt). There is no GitHub-hosted Composer registry
endpoint, and `gh release upload` attaches a binary asset to a Release — it does not make
the package installable via Composer.

To distribute a Composer package from a GitHub repo, use one of the real options above:

- a plain **VCS repository entry** pointing at the GitHub repo (option (c)), or
- **Satis / Private Packagist** indexing the GitHub repo (options (a)/(b)).

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

Marketplace publishing is a separate, manual process: the artefact is a zip uploaded
through the Marketplace developer portal (the EQP — Extension Quality Program — submission
flow), not a `composer publish` or any CLI push. This skill does NOT push to Marketplace —
but it does prepare the artefact.

The EQP zip must have the **module files at the ZIP root** — `registration.php`,
`composer.json`, and `etc/` sit at the top level of the archive, NOT nested inside a
`{Vendor}/{Module}/` subdirectory. Zip from *inside* the module folder so the paths are
relative to it:

```bash
( cd {module-folder} && zip -r ../{Module}-{Version}.zip . -x "Test/*" )
```

Save the zip alongside the release notes. The user uploads it via the Marketplace
developer portal manually.
