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

If `git config commit.gpgsign` is `true` AND `git config user.signingkey` is set,
create signed tags:

```bash
git tag -s -a {tag} -m "Release {Vendor}_{Module} {Version}"
```

Otherwise unsigned annotated:

```bash
git tag -a {tag} -m "Release {Vendor}_{Module} {Version}"
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
