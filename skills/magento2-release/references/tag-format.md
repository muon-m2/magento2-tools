# Tag Format

## Multi-Module Convention

```
{Vendor}_{Module}-{Version}
```

Examples:

- `Acme_OrderS3Export-1.4.0`
- `Acme_Catalog-2.0.0-rc.1`
- `Acme_Inventory-0.3.5`

## Single-Module Convention (Optional)

For a repo containing only one module, the simpler `v{Version}` is acceptable:

```
v1.4.0
```

The skill defaults to multi-module convention; pass `--simple-tag` to use the v-prefix
form.

## Signed Tags

Tag signing is controlled by `tag.gpgsign` (NOT `commit.gpgsign`, which governs commit
signing). If `git config tag.gpgsign` is `true` AND `git config user.signingkey` is set,
create signed tags:

```bash
git tag -s -m "Release {Vendor}_{Module} {Version}" {tag}
```

`-s` already implies an annotated tag, so `-s -a` is redundant — pass `-s -m` alone.

Otherwise unsigned annotated:

```bash
git tag -a -m "Release {Vendor}_{Module} {Version}" {tag}
```

## Annotated vs Lightweight

ALWAYS use annotated tags (`-a` or `-s`). Lightweight tags (`git tag {name}`) don't
carry metadata.

## Detecting Last Tag

```bash
git tag -l "{Vendor}_{Module}-*" --sort=-version:refname | head -1
```

Returns the most recent tag for this module. If none exist, the "since" base for
CHANGELOG generation is the initial commit.

**Pre-release caveat.** By default `--sort=-version:refname` treats a pre-release suffix
as sorting *after* the stable release (so `-1.0.0-rc.1` would rank above `-1.0.0`), which
contradicts semver — see the ordering in `references/semver-rules.md` where
`1.4.0-rc.1 < 1.4.0`. Git only sorts pre-releases correctly when `versionsort.suffix` is
configured. Set it once per repo so `-rc`, `-beta`, `-alpha` sort before the stable tag:

```bash
git config versionsort.suffix -alpha
git config versionsort.suffix -beta
git config versionsort.suffix -rc
```

If `versionsort.suffix` is NOT configured, treat the result as approximate: when the top
hit is a pre-release of an already-released stable version, the stable tag is the real
"last release". The skill should configure these suffixes (or compare candidates with the
semver rules) rather than trusting the raw `--sort` order for pre-release tags.

## Tag Collision

If a tag already exists:

- Refuse to overwrite.
- Suggest bumping the patch version: "Tag {Vendor}_{Module}-1.4.0 exists. Did you mean 1.4.1?"

## Listing All Module Releases

```bash
git tag -l "Acme_*" --sort=-version:refname
```

Returns all module-prefixed tags sorted by version.

## Tag Push

Tags are NOT pushed automatically. Phase 5 explicitly pushes:

```bash
git push origin {tag}
```

The user confirms before push.

## Tag Deletion (Discouraged)

If a tag was created in error:

```bash
git tag -d {tag}            # Local
git push origin :{tag}      # Remote
```

The skill refuses to delete tags. The user must run these manually.
