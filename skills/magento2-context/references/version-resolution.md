# Version Resolution

Algorithm for resolving `magento_version`, `edition`, `php_constraint`, `php_version`,
and `framework_constraint`.

## `edition` and `magento_version`

1. **`src/composer.json`** — read `require`:
    - `magento/product-community-edition` present → `edition = "open-source"`,
      `magento_version` = the constraint value (stripped of operators: `2.4.7-p1`).
    - `magento/product-enterprise-edition` present → `edition = "commerce"`,
      `magento_version` = the constraint value.
    - `mage-os/product-community-edition` present → `edition = "mage-os"`. **The
      constraint is NOT the `magento_version`** — see below.
    - Else fall through.
    - `resolution_source.edition` = `"src/composer.json:magento/product-{edition}-edition"`.

2. **Magento CLI** — `{magento_cli} --version` if runner available.
   Parse the output (`Magento CLI 2.4.7-p1`).
   `resolution_source.magento_version` = `"{magento_cli} --version"`.

3. **Ask the user.**
   `resolution_source.magento_version` = `"user prompt"`.

### Mage-OS: `magento_version` is the Magento BASE version

Mage-OS versions its distribution **independently** of Magento. Mage-OS `3.2.0` is based on
Magento `2.4.9`; `1.0.0` was based on `2.4.6-p2`. The distribution version is not a Magento
version and shares no numbering with one.

So for `edition = "mage-os"`, the `require` constraint must **not** be stripped into
`magento_version` the way it is for the `magento/*` metapackages. `magento_version` always
carries the **Magento base**, read from `extra.magento_version` on the
`mage-os/product-community-edition` entry in **`composer.lock`** (the installed, pinned
metadata — the root `composer.json` only constrains the distribution version):

- `resolution_source.magento_version` =
  `"composer.lock:mage-os/product-community-edition:extra.magento_version"`.
- No lock entry → `magento_version = null` plus a source explaining why. Falling back to
  the constraint is **forbidden**: it silently re-introduces the bug below.

> **Why this matters.** Every consumer compares `magento_version` against Magento ranges.
> Emitting `3.2.0` matches no `2.4.x` range anywhere — `cve-scan.sh`'s `version_in_range()`
> returns false for every advisory and the BC-break matrix finds nothing. The failure is
> **silent**: a vulnerable store reports clean. Guarded by
> `tests/test-context-mageos-base-version.sh`.

Mage-OS mirrors this same split in its own API — `ProductMetadata::getVersion()` returns
the Magento base (`2.4.9`) while `getDistributionVersion()` returns `3.2.0` — so the
distribution version is deliberately *not* stored in `magento_version` here either.

Two consequences worth knowing:

- **`extra.magento_version` under-reports the patch level.** Mage-OS 3.2.0 reports base
  `2.4.9` but carries Adobe's isolated patch `249-2026-07-001` on top. Treat the base as a
  floor, not an exact build.
- **Mage-OS declares no `replace`/`provide`** for the Magento metapackages and requires
  zero `magento/*` packages, so nothing detects it by grepping the lock for
  `magento/product-community-edition`.

### `distribution_version`

`distribution_version` records **what is actually installed**, as opposed to the Magento
base `magento_version` records.

| edition | `magento_version` | `distribution_version` |
|---|---|---|
| `open-source` | constraint on `magento/product-community-edition` | mirrors `magento_version` |
| `commerce` | constraint on `magento/product-enterprise-edition` | mirrors `magento_version` |
| `commerce-cloud` | constraint (enterprise, else cloud metapackage) | mirrors `magento_version` |
| `mage-os` | lock `extra.magento_version`, else `null` | lock package `version`, else stripped constraint |

Mirroring on the `magento/*` editions is truthful rather than a placeholder: those product
metapackages version in lockstep with Magento. Mage-OS is the only known distribution that
versions independently, so it is the only branch where the two fields differ.

The four Mage-OS shapes:

| composer.lock | `magento_version` | `distribution_version` |
|---|---|---|
| present, entry found | `2.4.9` (from `extra.magento_version`) | `3.2.0` (from lock `version`) |
| present, no entry | `null` + reason | `3.2.0` (from constraint) |
| absent | `null` + reason | `3.2.0` (from constraint) |
| absent, constraint unparseable | `null` + reason | `null` + reason |

Note the deliberate asymmetry: falling back to the composer.json constraint is **forbidden**
for `magento_version` (the constraint says nothing about the base — that is the bug guarded
by `tests/test-context-mageos-base-version.sh`) but **legitimate** for
`distribution_version`, because the constraint *is* a distribution constraint. When it is
used, the source string says `(constraint, not a pinned version)` so a reader can tell an
exact release from an approximation.

> **Why this field exists.** Mage-OS `3.0.0`, `3.1.0` and `3.2.0` all report
> `extra.magento_version: 2.4.9`, and only `3.2.0` carries Adobe's isolated security patch
> `249-2026-07-001` (shipped 2026-07-14). `magento_version` therefore cannot distinguish a
> patched Mage-OS store from an unpatched one; `distribution_version` is the only signal
> that can.

## `php_constraint`

1. **`src/composer.json`** — read `require.php`.
   `resolution_source.php_constraint` = `"src/composer.json:require.php"`.

2. **`CLAUDE.md`** — look for `PHP constraint:` or `PHP version:` line.

3. **Ask the user.**

The constraint format is preserved verbatim (e.g. `~8.2.0`, `^8.1`, `>=8.1 <8.4`). Do not
normalize.

## `php_version`

1. **Runner probe** — `{runner} php -r 'echo PHP_VERSION;'` if `runner` is non-null.
   `resolution_source.php_version` = `"{runner} php -r echo PHP_VERSION"`.

2. **`null`** if no runner — record `resolution_source.php_version = "no runner"`.

This is the **actual installed** PHP version, distinct from the constraint.

## `framework_constraint`

1. **`src/composer.json`** — read `require.magento/framework`.
   `resolution_source.framework_constraint` = `"src/composer.json:require.magento/framework"`.

2. **`null`** if not present (rare; only in very stripped-down installs — **and always on
   Mage-OS**, see below).

On Mage-OS this is `null` by construction, not by accident: the fork ships its framework as
`mage-os/framework` (plus `-amqp`, `-bulk`, `-message-queue`, `-stomp`) and its metapackage
requires **zero** `magento/*` packages, so `require.magento/framework` is never present.
Consumers must treat a null `framework_constraint` on `edition = "mage-os"` as expected
rather than as a broken install.

## Edge Cases

| Case                                                                | Behaviour                                                                 |
|---------------------------------------------------------------------|---------------------------------------------------------------------------|
| Both community and enterprise editions in composer.json             | Prefer enterprise; record both in `resolution_source`.                    |
| Mage-OS present but no `composer.lock`                              | `magento_version = null` + source says why. Never fall back to the constraint. |
| `composer.json` constraint uses an alias (e.g. `dev-main as 2.4.7`) | **Not parsed.** `magento_version = null` + a source naming the constraint; `cve-scan.sh` then warns that the matcher did not run. See below. |
| Constraint is a range/wildcard (`>=2.4.6 <2.4.8`, `2.4.*`, `^2.4`)  | **Not parsed.** `magento_version = null` + a source naming the constraint. See below. |
| `magento_version` looks invalid (no major/minor/patch)              | **Rejected, not accepted** — `null` + a stated reason. See below.         |
| Magento CLI version mismatches composer.json                        | Trust composer.json; warn user.                                           |
| PHP probe fails (extension missing, etc.)                           | `php_version = null`; downstream skills know to skip PHP-specific checks. |

### Why unparseable constraints resolve to `null` rather than a best effort

`magento_version` is only ever set from a constraint that resolves to a **single, exact
version** (`^[0-9]+\.[0-9]+\.[0-9]+(-p[0-9]+)?$`). Anything else — a range, a wildcard, a
two-component `^2.4`, a `dev-main as 2.4.7` alias — yields `null` plus a
`resolution_source` naming the raw constraint, and `cve-scan.sh` then warns that the
Magento CVE matcher did not run.

This is deliberate, and it is a **security** property rather than a stylistic one.

> **REGRESSION TOMBSTONE (CTX-Compound).** The resolver used to strip operators with
> `sed -E 's/[~^>=<* ]//g'` and emit whatever fell out. That does not fail closed — it
> silently invents versions:
>
> | constraint | old `magento_version` | `parse_version()` read it as |
> |---|---|---|
> | `>=2.4.6 <2.4.8` | `2.4.62.4.8` | `(2, 4, 62, 0)` — a plausible **wrong** version |
> | `2.4.*` | `2.4.` | `None` |
> | `^2.4` | `2.4` | `None` |
>
> A store on 2.4.6 inside an affected range therefore compared as "2.4.62", fell outside
> every advisory range, and **reported clean** — with nothing on stderr. A wrong version
> that compares cleanly is worse than no version at all, because no version is at least
> visible. Guarded by `tests/test-context-magento-version-compound.sh`, with the
> matcher-side warning guarded by `tests/test-cve-garbage-version-warning.sh`.

So: do **not** "improve" this by reinstating a best-effort strip, and do not treat the
`null` as a gap to be filled by guessing. If a project pins with a range or an alias, the
honest answer is that the exact version is unknown — resolve it from `composer.lock`, the
Magento CLI, or the user, per the resolution order above.
