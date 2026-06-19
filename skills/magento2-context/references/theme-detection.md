# Theme Detection

Algorithm for resolving `theme.frontend` and `theme.adminhtml`.

## Honest gaps rule

Both fields are emitted as `null` when no evidence-backed value can be determined. The
resolver **never** silently defaults to `"custom"` or `"magento/backend"`. Consumers
that see `null` MUST treat it as "active theme unknown" and not assume Luma defaults.

Each field is accompanied by a `theme.{field}_source` string in the JSON. When the
value is `null`, the source is `null` or an empty string. When the value is non-null,
the source describes how it was derived (e.g. `"src/app/etc/config.php:themes[].area=frontend"`).

## `theme.frontend`

1. **`app/etc/config.php` (authoritative).** If the file exists, iterate the `themes`
   array and pick the first entry whose `area = "frontend"`. Use its `theme_path`.
    - `theme.frontend = "<theme_path>"`.
    - `theme.frontend_source = "<config.php path>:themes[].area=frontend"`.
    - The resolver checks `src/app/etc/config.php` first, then `app/etc/config.php`.

2. **Hyva package presence (heuristic).** If step 1 produced no result and
   `composer.json` requires any `hyva-themes/*` package, classify as `hyva`.
    - `theme.frontend = "hyva"`.
    - `theme.frontend_source = "<composer.json>:hyva-themes/* dependency (installed, active-theme unverified)"`.
    - The source string explicitly notes this is package-presence evidence, not
      active-theme confirmation.

3. **No evidence.** Leave `theme.frontend = null`. Do **not** fall through to
   `"custom"`. Downstream skills that need the active theme must surface an honest
   "unknown" rather than acting on a fabricated default.

## `theme.adminhtml`

Resolved the same way as `theme.frontend`, from the `area = "adminhtml"` entry in
`app/etc/config.php`. When no entry exists, leave it `null`. Do **not** default to
`Magento/backend` — that assumption was previously baked in and produced misleading
"resolved" state for projects that hadn't yet run setup.

## Breeze detection (`theme.breeze`)

Swissup [Breezefront](https://breezefront.com) is a frontend framework that replaces
RequireJS/Knockout/jQuery with a Cash-based stack. It is detected independently of
`theme.frontend` and emitted as a `theme.breeze` object:

```json
"breeze": { "installed": false, "active": false, "parent": null, "packages": [], "source": null }
```

1. **`installed`** — `true` when `composer.json` `require` lists any `swissup/breeze-*`
   package (`breeze-blank`, `breeze-evolution`, `breeze-enterprise`) **or**
   `swissup/module-breeze`. `packages` collects every matched package name.

2. **`active`** — `true` only when the resolved `theme.frontend`, or any `<parent>` in its
   `app/design/frontend/<code>/theme.xml` chain (walked up to 10 hops), is a Swissup Breeze
   theme (its code contains `breeze`). `parent` is set to that Breeze theme code (e.g.
   `Swissup/breeze-evolution`). Vendor-installed Breeze themes that are *directly* active are
   matched by the same "code contains breeze" rule.

3. **Honest gaps.** With no evidence, `installed`/`active` stay `false`, `parent` is `null`.
   The walk only follows `app/design` theme.xml files, so a custom child theme whose Breeze
   parent lives in `vendor/` is reported via `installed` (package presence) even when the
   chain walk cannot complete; `source` records which signal fired.

### Why it matters

The three `magento2-breeze-*` skills (`-child-theme`, `-module-adapt`, `-compat-audit`)
**refuse to run** when `theme.breeze.installed` is `false` and instead print the install
path (`composer require swissup/breeze-evolution && bin/magento setup:upgrade --safe-mode=1
&& bin/magento marketplace:package:install swissup/breeze-evolution`). `compat-audit` also
reads `active` to phrase its verdict ("compatible with the active Breeze theme" vs
"Breeze installed but not active").

## Output values

`theme.frontend` is one of:

- `null` when no evidence is available
- `"hyva"` (package-presence heuristic)
- A concrete theme code from `config.php` (e.g. `"Magento/luma"`, `"Acme/checkout"`)

`theme.adminhtml` is one of:

- `null` when no evidence is available
- A concrete theme code from `config.php` (e.g. `"Magento/backend"`, `"Acme/admin"`)

## Why it matters

Downstream skills behave differently per theme:

- `magento2-frontend-create` should refuse to generate Hyva/Luma-specific scaffolds
  when `theme.frontend` is `null`; instead, ask the user.
- `magento2-module-review` reads `theme.frontend_source` to decide whether RequireJS
  checks apply; if the source contains "installed, active-theme unverified", the
  reviewer notes the uncertainty in the finding.
- `magento2-module-create` `frontend_ui` surface should also branch on the source
  string, not just the value.

## Consumer pattern

```bash
THEME=$(jq -r '.theme.frontend // "null"' .claude/.cache/magento2-context.json)
SRC=$(jq   -r '.theme.frontend_source // ""'   .claude/.cache/magento2-context.json)

if [ "$THEME" = "null" ]; then
    echo "active frontend theme unknown; cannot generate theme-specific scaffold" >&2
    exit 1
fi
```
