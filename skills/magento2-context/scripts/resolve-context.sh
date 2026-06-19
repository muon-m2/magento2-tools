#!/usr/bin/env bash
# =============================================================================
# Resolve Magento 2 project context and emit JSON to stdout.
#
# Usage:
#   ./scripts/resolve-context.sh [--no-cache]
#
# Reads from project root (./, ./src/, ./CLAUDE.md, ./.claude/.cache/).
# Returns a single JSON object matching the schema in SKILL.md.
# Exits 0 on success, even when some fields can't be resolved (those become null).
# =============================================================================
set -euo pipefail

CACHE_FILE=".claude/.cache/magento2-context.json"
USE_CACHE=true
[[ "${1:-}" == "--no-cache" ]] && USE_CACHE=false

# --- JSON parser (PHP-first, jq fallback) ---
# Usage: jget <file> <jq-path-or-php-path>
# We pass two forms because jq syntax differs from PHP array access.
jget_php() {
    local file="$1"; local path="$2"
    if command -v php >/dev/null 2>&1; then
        php -r "
            \$d = json_decode(file_get_contents('$file'), true);
            if (!is_array(\$d)) { exit(0); }
            \$keys = explode('.', '$path');
            \$v = \$d;
            foreach (\$keys as \$k) {
                if (is_array(\$v) && array_key_exists(\$k, \$v)) { \$v = \$v[\$k]; }
                else { exit(0); }
            }
            if (is_scalar(\$v)) { echo \$v; }
        " 2>/dev/null || true
    fi
}

# --- Helpers ---
# Portable JSON string escaping. Tab handling uses a literal tab via printf rather than
# sed's `\t` (BSD/macOS sed treats `\t` in the pattern as the letter "t", which corrupted
# every "t" in a value). CR/LF are stripped with tr, which understands \r/\n on GNU and BSD.
json_str() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g' \
        | sed "s/$(printf '\t')/\\\\t/g" \
        | tr -d '\r' | tr -d '\n'
}
json_or_null() { if [[ -z "$1" || "$1" == "null" ]]; then printf 'null'; else printf '"%s"' "$(json_str "$1")"; fi; }
# Serialize a comma-separated list as a JSON array of strings ("" → []).
json_array_from_csv() {
    local csv="$1"; local out="["; local first=1; local item
    local IFS=','
    for item in $csv; do
        [[ -z "$item" ]] && continue
        [[ $first -eq 0 ]] && out+=","
        out+="\"$(json_str "$item")\""
        first=0
    done
    out+="]"
    printf '%s' "$out"
}
# runner is special: an EMPTY string is a real value in bare mode (callers compose
# `${runner} php ...`), so it must serialize as "" — never null. Only the no-environment
# case (runner_kind == "null") emits JSON null.
runner_json() { if [[ "${RUNNER_KIND}" == "null" ]]; then printf 'null'; else printf '"%s"' "$(json_str "${RUNNER}")"; fi; }

# --- Cache key (composer.lock + composer.json + CLAUDE.md) ---
# Portable SHA-256. macOS has no `sha256sum` (it ships `shasum`); calling a missing
# sha256sum under `set -e` hard-exited the whole resolver on stock macOS. Fall back through
# shasum and openssl, then a size-based pseudo-key as a last resort (still busts the cache on
# content change because file size is part of it for most edits).
hash_file() {
    if [[ ! -f "$1" ]]; then echo "absent"; return; fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" | awk '{print $NF}'
    else
        echo "size-$(wc -c < "$1" | tr -d ' ')"
    fi
}
LOCK_FILE=""
if [[ -f "composer.lock" ]]; then LOCK_FILE="composer.lock"
elif [[ -f "src/composer.lock" ]]; then LOCK_FILE="src/composer.lock"; fi
JSON_FILE=""
if [[ -f "composer.json" ]]; then JSON_FILE="composer.json"
elif [[ -f "src/composer.json" ]]; then JSON_FILE="src/composer.json"; fi
CLAUDE_FILE=""
[[ -f "CLAUDE.md" ]] && CLAUDE_FILE="CLAUDE.md"
M2_FILE=""
[[ -f ".claude/m2.json" ]] && M2_FILE=".claude/m2.json"

# The cache key folds in everything that can change resolution: the lock/json/CLAUDE.md
# hashes, the optional .claude/m2.json override file, and the M2_* env overrides — so
# changing any override busts the cache instead of returning a stale result.
CACHE_KEY="lock:$(hash_file "${LOCK_FILE:-/dev/null}");json:$(hash_file "${JSON_FILE:-/dev/null}");claude:$(hash_file "${CLAUDE_FILE:-/dev/null}");m2:$(hash_file "${M2_FILE:-/dev/null}");env:${M2_MAGENTO_ROOT:-}|${M2_PHP_CONTAINER:-}"

# --- Cache check ---
# The cache key busts on content change (lock/json/CLAUDE.md/m2.json hashes + env overrides),
# but runner state is NOT in the key — a container can stop without any of those changing. A
# TTL bounds how long that stale runner can be served: a cache older than the TTL is
# re-resolved even on a key match. Default 24h (the documented value); M2_CACHE_TTL overrides
# (seconds); 0 disables the TTL.
CACHE_TTL="${M2_CACHE_TTL:-86400}"
if [[ "$USE_CACHE" == "true" && -f "$CACHE_FILE" ]]; then
    cache_stale=0
    if [[ "$CACHE_TTL" -gt 0 ]] && find "$CACHE_FILE" -mmin +"$((CACHE_TTL / 60))" 2>/dev/null | grep -q .; then
        cache_stale=1
    fi
    cached_key=$(jget_php "$CACHE_FILE" "cacheKey")
    if [[ "$cache_stale" == "0" && -n "$cached_key" && "$cached_key" == "$CACHE_KEY" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# --- Magento root ---
# Detect the layout rather than assuming one. Repo-root installs have bin/magento or
# app/code at the top level; "src/" composer-template installs nest them under src/.
# M2_MAGENTO_ROOT (env) or .claude/m2.json "magento_root" override the probe. Resolved BEFORE
# vendor detection so the vendor scan looks in the correct app/code (CTX-5: a repo-root
# layout previously yielded vendor=null because the scan hardcoded src/app/code).
MAGENTO_ROOT=""
if [[ -n "${M2_MAGENTO_ROOT:-}" ]]; then
    MAGENTO_ROOT="$M2_MAGENTO_ROOT"
elif [[ -f ".claude/m2.json" ]] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_ROOT=$(python3 -c "import json; print(json.load(open('.claude/m2.json')).get('magento_root',''))" 2>/dev/null || echo "")
fi
if [[ -z "$MAGENTO_ROOT" ]]; then
    if [[ -f "bin/magento" || -d "app/code" ]]; then
        MAGENTO_ROOT="."
    elif [[ -f "src/bin/magento" || -d "src/app/code" ]]; then
        MAGENTO_ROOT="src"
    else
        MAGENTO_ROOT="."   # neutral default when nothing is detectable yet
    fi
fi
MODULE_DIR="${MAGENTO_ROOT}/app/code"
[[ "$MAGENTO_ROOT" == "." ]] && MODULE_DIR="app/code"

# --- Vendor resolution ---
VENDOR=""
VENDOR_SRC=""

# 1. CLAUDE.md
if [[ -f "CLAUDE.md" ]]; then
    raw=$(grep -E '^[[:space:]]*Vendor prefix[[:space:]]*:' CLAUDE.md | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/\*\*//g; s/`//g' | xargs || echo "")
    if [[ -n "$raw" && "$raw" =~ ^[A-Za-z]+$ ]]; then
        # Uppercase the first letter portably — sed's \U is GNU-only (no-op on BSD/macOS sed).
        VENDOR=$(printf '%s' "$raw" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
        VENDOR_SRC="CLAUDE.md:Vendor prefix"
    fi
fi

# 2. {MODULE_DIR} inspection — honours the detected layout, so repo-root (app/code) and
# src/ (src/app/code) projects both resolve a vendor (CTX-5).
if [[ -z "$VENDOR" && -d "$MODULE_DIR" ]]; then
    candidates=()
    while IFS= read -r dir; do
        name=$(basename "$dir")
        [[ "$name" != "Magento" ]] && candidates+=("$name")
    done < <(find "$MODULE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    if [[ ${#candidates[@]} -eq 1 ]]; then
        VENDOR="${candidates[0]}"
        VENDOR_SRC="${MODULE_DIR}/${VENDOR}/ (single non-Magento dir)"
    fi
fi

# 3. composer.json `require` package-name inspection (references/vendor-resolution.md step 3).
# Pick the most frequent letters-only "{name}/module-*" vendor prefix; a tie OR a vendor that
# isn't pure letters (digits/hyphens — not a valid PascalCase Magento vendor per
# vendor-resolution.md) falls through to vendor=null so the LLM resolver asks the user. The
# composer path is passed to PHP via argv (never spliced into the code literal), so a crafted
# magento_root cannot break out of the string.
if [[ -z "$VENDOR" ]] && command -v php >/dev/null 2>&1; then
    vendor_composer=""
    [[ -f "${MAGENTO_ROOT%/}/composer.json" ]] && vendor_composer="${MAGENTO_ROOT%/}/composer.json"
    [[ -z "$vendor_composer" && -f "composer.json" ]] && vendor_composer="composer.json"
    if [[ -n "$vendor_composer" ]]; then
        cand=$(php -r '
            $d = json_decode(file_get_contents($argv[1]), true);
            $req = (is_array($d) && isset($d["require"]) && is_array($d["require"])) ? $d["require"] : [];
            $counts = [];
            foreach ($req as $k => $v) {
                if (preg_match("#^([a-z]+)/module-#", (string) $k, $m)) {
                    $counts[$m[1]] = ($counts[$m[1]] ?? 0) + 1;
                }
            }
            if (!$counts) { exit(0); }
            arsort($counts);
            $vals = array_values($counts);
            if (count($vals) > 1 && $vals[0] === $vals[1]) { exit(0); }
            echo array_key_first($counts);
        ' "$vendor_composer" 2>/dev/null || echo "")
        if [[ -n "$cand" && "$cand" =~ ^[a-z]+$ ]]; then
            VENDOR=$(printf '%s' "$cand" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
            VENDOR_SRC="${vendor_composer}:require (most-frequent {name}/module-* vendor)"
        fi
    fi
fi

VENDOR_LOWER=""
if [[ -n "$VENDOR" ]]; then
    VENDOR_LOWER=$(printf '%s' "$VENDOR" | tr '[:upper:]' '[:lower:]')
fi

# --- Runner resolution ---
# RUNNER is the command-prefix that places subsequent argv inside a PHP-capable
# environment. For docker-based projects it is e.g. "docker compose exec -T -u magento php".
# For bare-host PHP it is EMPTY — callers compose argv directly (e.g. `${RUNNER} php -r ...`
# becomes ` php -r ...`, which works).
# RUNNER_KIND captures the mode for downstream consumers that need structured data.
RUNNER=""
RUNNER_KIND="null"
RUNNER_SRC="none"
DOCKER_USER="magento"

# CLAUDE.md hint
if [[ -f "CLAUDE.md" ]]; then
    hint=$(grep -E '^[[:space:]]*(Docker prefix|Runner)[[:space:]]*:' CLAUDE.md | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/`//g' | xargs || echo "")
    if [[ -n "$hint" ]]; then
        RUNNER="$hint"
        RUNNER_KIND="custom"
        RUNNER_SRC="CLAUDE.md hint"
    fi
    duser=$(grep -E '^[[:space:]]*Docker user[[:space:]]*:' CLAUDE.md | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | xargs || echo "")
    [[ -n "$duser" ]] && DOCKER_USER="$duser"
fi

# Docker compose probe. The PHP service is named differently across stacks: generic `php`,
# markshust `phpfpm`, Warden `php-fpm`, ddev `web`. Match a running service by name instead
# of requiring a literal `php` (CTX-8), preferring php-named services over the generic `web`.
if [[ "$RUNNER_KIND" == "null" ]] && command -v docker >/dev/null 2>&1; then
    running_svcs="$(docker compose ps --services --filter status=running 2>/dev/null || true)"
    compose_svc="$(printf '%s\n' "$running_svcs" | grep -iE '^php(-?fpm)?$' | head -1 || true)"
    [[ -z "$compose_svc" ]] && compose_svc="$(printf '%s\n' "$running_svcs" | grep -iE '^(fpm|web)$' | head -1 || true)"
    if [[ -n "$compose_svc" ]]; then
        RUNNER="docker compose exec -T -u ${DOCKER_USER} ${compose_svc}"
        RUNNER_KIND="docker-compose"
        RUNNER_SRC="docker compose ps probe (service: ${compose_svc})"
    fi
fi

# Bare docker exec for a known container.
# Resolution order (most specific wins): M2_PHP_CONTAINER env var >
# .claude/m2.json "php_container" > generic name patterns. A configured container
# that is not actually running falls through to the patterns.
if [[ "$RUNNER_KIND" == "null" ]] && command -v docker >/dev/null 2>&1; then
    container=""
    container_src=""
    if [[ -n "${M2_PHP_CONTAINER:-}" ]]; then
        container="$M2_PHP_CONTAINER"
        container_src="M2_PHP_CONTAINER env"
    elif [[ -f ".claude/m2.json" ]] && command -v python3 >/dev/null 2>&1; then
        container=$(python3 -c "import json; print(json.load(open('.claude/m2.json')).get('php_container',''))" 2>/dev/null || echo "")
        [[ -n "$container" ]] && container_src=".claude/m2.json"
    fi
    # Drop a configured-but-not-running container so the patterns can try.
    if [[ -n "$container" ]] && ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container"; then
        container=""
        container_src=""
    fi
    # Generic fallback patterns — match magento*/m2* php containers, any "<name>-php"
    # (optionally suffixed "-1"), or a bare "php" container, without naming any project.
    if [[ -z "$container" ]]; then
        container=$(docker ps --format '{{.Names}}' 2>/dev/null \
            | grep -E '(magento.*php|m2.*php|.*-php([_-][0-9]+)?$|^php([_-][0-9]+)?$)' \
            | head -1 || echo "")
        [[ -n "$container" ]] && container_src="docker ps name pattern"
    fi
    if [[ -n "$container" ]]; then
        RUNNER="docker exec -i ${container}"
        RUNNER_KIND="docker-exec"
        RUNNER_SRC="docker ps probe (${container}) via ${container_src}"
    fi
fi

# Bare host PHP — RUNNER stays empty; downstream `${RUNNER} php -r ...` works.
if [[ "$RUNNER_KIND" == "null" ]] && command -v php >/dev/null 2>&1; then
    if php --version >/dev/null 2>&1; then
        RUNNER=""
        RUNNER_KIND="bare"
        RUNNER_SRC="bare php on PATH"
    fi
fi

# --- Magento CLI ---
MAGENTO_CLI="null"
MAGENTO_CLI_SRC="not available"
if [[ "$RUNNER_KIND" != "null" ]]; then
    # Runner-backed modes (docker-compose/exec/custom) execute with the Magento root as the
    # working dir, so the CLI is bin/magento. Bare host PHP runs from the workspace cwd, so in
    # a src/ layout it must be the layout-aware path src/bin/magento — a bare "bin/magento"
    # was a broken relative path there (CTX-6).
    cli_path="bin/magento"
    if [[ "$RUNNER_KIND" == "bare" && "$MAGENTO_ROOT" != "." ]]; then
        cli_path="${MAGENTO_ROOT%/}/bin/magento"
    fi
    if [[ -f "${MAGENTO_ROOT}/bin/magento" || -f "bin/magento" ]]; then
        # ${RUNNER} is empty for bare mode, so leading-space collapses naturally.
        MAGENTO_CLI="$(echo "${RUNNER} ${cli_path}" | sed 's/^ //')"
        MAGENTO_CLI_SRC="{runner} + ${cli_path} exists"
    fi
fi

# --- Composer ---
COMPOSER_CMD="null"
COMPOSER_CMD_SRC="not available"
if [[ "$RUNNER_KIND" == "docker-compose" || "$RUNNER_KIND" == "docker-exec" ]]; then
    COMPOSER_CMD="${RUNNER} composer"
    COMPOSER_CMD_SRC="{runner} + composer"
elif command -v composer >/dev/null 2>&1; then
    COMPOSER_CMD="composer"
    COMPOSER_CMD_SRC="composer on PATH"
fi

# --- Edition & Magento version ---
EDITION="null"
EDITION_SRC=""
MAGENTO_VERSION="null"
MAGENTO_VERSION_SRC=""
PHP_CONSTRAINT="null"
FRAMEWORK_CONSTRAINT="null"

COMPOSER_JSON="${MAGENTO_ROOT}/composer.json"
[[ ! -f "$COMPOSER_JSON" && -f "composer.json" ]] && COMPOSER_JSON="composer.json"

if [[ -f "$COMPOSER_JSON" ]] && command -v php >/dev/null 2>&1; then
    ent=$(jget_php "$COMPOSER_JSON" "require.magento/product-enterprise-edition")
    com=$(jget_php "$COMPOSER_JSON" "require.magento/product-community-edition")
    cloud=$(jget_php "$COMPOSER_JSON" "require.magento/magento-cloud-metapackage")
    mageos=$(jget_php "$COMPOSER_JSON" "require.mage-os/product-community-edition")
    if [[ -n "$cloud" ]]; then
        # Commerce Cloud ships the cloud metapackage on top of the enterprise edition.
        EDITION="commerce-cloud"
        MAGENTO_VERSION=$(printf '%s' "${ent:-$cloud}" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:magento/magento-cloud-metapackage"
        MAGENTO_VERSION_SRC="$EDITION_SRC"
    elif [[ -n "$ent" ]]; then
        EDITION="commerce"
        MAGENTO_VERSION=$(printf '%s' "$ent" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:magento/product-enterprise-edition"
        MAGENTO_VERSION_SRC="$EDITION_SRC"
    elif [[ -n "$com" ]]; then
        EDITION="open-source"
        MAGENTO_VERSION=$(printf '%s' "$com" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:magento/product-community-edition"
        MAGENTO_VERSION_SRC="$EDITION_SRC"
    elif [[ -n "$mageos" ]]; then
        # Mage-OS — the community fork; its product metapackage is mage-os/product-community-edition.
        EDITION="mage-os"
        MAGENTO_VERSION=$(printf '%s' "$mageos" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:mage-os/product-community-edition"
        MAGENTO_VERSION_SRC="$EDITION_SRC"
    fi
    pc=$(jget_php "$COMPOSER_JSON" "require.php")
    [[ -n "$pc" ]] && PHP_CONSTRAINT="$pc"
    fc=$(jget_php "$COMPOSER_JSON" "require.magento/framework")
    [[ -n "$fc" ]] && FRAMEWORK_CONSTRAINT="$fc"
fi

# --- PHP version probe ---
PHP_VERSION="null"
PHP_VERSION_SRC=""
if [[ "$RUNNER_KIND" != "null" ]]; then
    # `${RUNNER} php -r ...` works for docker (wrapper + php) and bare (empty + php).
    pv=$(${RUNNER} php -r 'echo PHP_VERSION;' 2>/dev/null || echo "")
    if [[ -n "$pv" ]]; then
        PHP_VERSION="$pv"
        PHP_VERSION_SRC="${RUNNER_KIND}:php -r"
    fi
fi

# --- Theme ---
# Probe app/etc/config.php for the active theme before falling back to composer dependency
# evidence. If nothing is found, leave frontend null and admin null — honest gaps rule.
THEME_FRONTEND="null"
THEME_FRONTEND_SRC=""
THEME_ADMIN="null"
THEME_ADMIN_SRC=""

CONFIG_PHP=""
[[ -f "${MAGENTO_ROOT}/app/etc/config.php" ]] && CONFIG_PHP="${MAGENTO_ROOT}/app/etc/config.php"
[[ -z "$CONFIG_PHP" && -f "app/etc/config.php" ]] && CONFIG_PHP="app/etc/config.php"

if [[ -n "$CONFIG_PHP" ]] && command -v php >/dev/null 2>&1; then
    # config.php's `themes` array is the list of REGISTERED themes, NOT the active one (the
    # active theme is in the DB: core_config_data design/theme/theme_id). The old code took
    # the FIRST frontend theme, which is almost always Magento/blank — steering frontend work
    # to Luma even on a custom/Hyva storefront (CTX-2). We instead prefer a non-Magento
    # registered frontend theme (a custom/Hyva theme is far more likely the active one than
    # the base), and mark the source as unverified.
    active=$(php -r "
        \$d = include '$CONFIG_PHP';
        \$themes = \$d['themes'] ?? [];
        \$frontend = []; \$admin = [];
        foreach (\$themes as \$code => \$row) {
            \$area = \$row['area'] ?? '';
            \$path = \$row['theme_path'] ?? \$code;
            if (\$area === 'frontend') { \$frontend[] = \$path; }
            if (\$area === 'adminhtml') { \$admin[] = \$path; }
        }
        \$pick = '';
        foreach (\$frontend as \$p) { if (stripos(\$p, 'Magento/') !== 0) { \$pick = \$p; break; } }
        if (\$pick === '') { foreach (\$frontend as \$p) { if (\$p !== 'Magento/blank') { \$pick = \$p; break; } } }
        if (\$pick === '' && \$frontend) { \$pick = \$frontend[0]; }
        echo \$pick . '|' . (\$admin[0] ?? '');
    " 2>/dev/null || echo "|")
    fe="${active%%|*}"; ah="${active##*|}"
    if [[ -n "$fe" ]]; then
        THEME_FRONTEND="$fe"
        THEME_FRONTEND_SRC="${CONFIG_PHP}:themes[] registered (active theme unverified — confirm via 'config:show design/theme/theme_id')"
    fi
    if [[ -n "$ah" ]]; then
        THEME_ADMIN="$ah"
        THEME_ADMIN_SRC="${CONFIG_PHP}:themes[].area=adminhtml (registered)"
    fi
fi

# Hyva-from-composer is evidence of an installed package, not necessarily the active theme.
# Only set if we still have no frontend evidence.
if [[ "$THEME_FRONTEND" == "null" && -f "$COMPOSER_JSON" ]] && command -v php >/dev/null 2>&1; then
    has_hyva=$(php -r "
        \$d = json_decode(file_get_contents('$COMPOSER_JSON'), true);
        \$r = \$d['require'] ?? [];
        foreach (\$r as \$k => \$v) { if (strpos(\$k, 'hyva-themes/') === 0) { echo 'yes'; exit; } }
    " 2>/dev/null)
    if [[ "$has_hyva" == "yes" ]]; then
        THEME_FRONTEND="hyva"
        THEME_FRONTEND_SRC="${COMPOSER_JSON}:hyva-themes/* dependency (installed, active-theme unverified)"
    fi
fi

# --- Breeze (Swissup Breezefront) detection ---
# installed = any swissup/breeze-* or swissup/module-breeze package is required in composer.
# active    = the resolved frontend theme, or any theme.xml <parent> in its (app/design) chain,
#             is a Swissup Breeze theme (code contains "breeze"). Honest-gaps rule: when there
#             is no evidence, installed/active stay false, parent null. Consumed by the
#             magento2-breeze-* skills, which refuse to run when installed is false.
BREEZE_INSTALLED="false"
BREEZE_ACTIVE="false"
BREEZE_PARENT="null"
BREEZE_PACKAGES=""
BREEZE_SRC=""

if [[ -f "$COMPOSER_JSON" ]] && command -v php >/dev/null 2>&1; then
    BREEZE_PACKAGES=$(php -r '
        $d = json_decode(file_get_contents($argv[1]), true);
        $r = (is_array($d) && isset($d["require"]) && is_array($d["require"])) ? $d["require"] : [];
        $hit = [];
        foreach ($r as $k => $v) {
            if (preg_match("#^swissup/(breeze-|module-breeze)#", (string) $k)) { $hit[] = $k; }
        }
        echo implode(",", $hit);
    ' "$COMPOSER_JSON" 2>/dev/null || echo "")
    if [[ -n "$BREEZE_PACKAGES" ]]; then
        BREEZE_INSTALLED="true"
        BREEZE_SRC="${COMPOSER_JSON}:require swissup/breeze-* present"
    fi
fi

# Walk the active frontend theme's parent chain (app/design only) for a Breeze ancestor.
if [[ "$THEME_FRONTEND" != "null" && "$THEME_FRONTEND" != "hyva" ]] && command -v php >/dev/null 2>&1; then
    breeze_parent=$(php -r '
        $root = rtrim($argv[1], "/"); $cur = $argv[2]; $seen = [];
        for ($i = 0; $i < 10; $i++) {
            if ($cur === "" || isset($seen[$cur])) { break; }
            $seen[$cur] = true;
            if (stripos($cur, "breeze") !== false) { echo $cur; exit; }
            $xml = $root . "/app/design/frontend/" . $cur . "/theme.xml";
            if (!is_file($xml)) { break; }
            $c = (string) file_get_contents($xml);
            if (preg_match("#<parent>\s*([^<]+?)\s*</parent>#", $c, $m)) { $cur = trim($m[1]); }
            else { break; }
        }
    ' "$MAGENTO_ROOT" "$THEME_FRONTEND" 2>/dev/null || echo "")
    if [[ -n "$breeze_parent" ]]; then
        BREEZE_ACTIVE="true"
        BREEZE_PARENT="$breeze_parent"
        if [[ -z "$BREEZE_SRC" ]]; then
            BREEZE_SRC="theme.frontend parent chain resolves to ${breeze_parent}"
        else
            BREEZE_SRC="${BREEZE_SRC}; theme.frontend chain → ${breeze_parent}"
        fi
    fi
fi

# --- Tools ---
probe_tool() {
    local key="$1"; local probe="$2"; local resolved="$3"
    if eval "$probe" >/dev/null 2>&1; then
        printf '"%s"' "$resolved"
    else
        printf 'null'
    fi
}

# Project-local vendor/bin tools are layout- and runner-aware. In a "src/" layout the host
# path is ${MAGENTO_ROOT}/vendor/bin/<tool>, but a docker runner's working dir is the Magento
# root, so the same tool is reachable as vendor/bin/<tool>. Downstream callers invoke
# `${RUNNER} <resolved>`, so for runner-backed modes we emit the runner-relative
# "vendor/bin/<tool>" (consistent with how MAGENTO_CLI is built); for bare mode we emit the
# host path from the workspace root. Falls back to a runner probe (`${RUNNER} test -x ...`,
# the runner-awareness rule from references/tool-probe.md) for tools that live only inside
# the container image, not on the host mount — guarded on LOCK_FILE so the hermetic contract
# test (empty workspace, no composer.lock) never shells into a container.
probe_vendor_tool() {
    local tool="$1"
    local host_path="${MAGENTO_ROOT%/}/vendor/bin/${tool}"
    [[ "$MAGENTO_ROOT" == "." ]] && host_path="vendor/bin/${tool}"

    if [[ -x "$host_path" ]]; then
        case "$RUNNER_KIND" in
            docker-compose|docker-exec|custom) printf '"vendor/bin/%s"' "$tool" ;;
            *)                                 printf '"%s"' "$host_path" ;;
        esac
        return
    fi

    case "$RUNNER_KIND" in
        docker-compose|docker-exec|custom)
            if [[ -n "$LOCK_FILE" ]] && ${RUNNER} test -x "vendor/bin/${tool}" >/dev/null 2>&1; then
                printf '"vendor/bin/%s"' "$tool"
                return
            fi
            ;;
    esac

    printf 'null'
}

T_PHPCS=$(probe_vendor_tool phpcs)
T_PHPSTAN=$(probe_vendor_tool phpstan)
T_PHPUNIT=$(probe_vendor_tool phpunit)
T_PHPMD=$(probe_vendor_tool phpmd)
T_RECTOR=$(probe_vendor_tool rector)
T_PSALM=$(probe_vendor_tool psalm)
T_PHPCSFIXER=$(probe_vendor_tool php-cs-fixer)
T_XMLLINT=$(probe_tool xmllint 'command -v xmllint' "xmllint")
T_COMPOSER=$(probe_tool composer 'command -v composer' "composer")
T_SEMGREP=$(probe_tool semgrep 'command -v semgrep' "semgrep")
T_GITLEAKS=$(probe_tool gitleaks 'command -v gitleaks' "gitleaks")
T_TRUFFLEHOG=$(probe_tool trufflehog 'command -v trufflehog' "trufflehog")
T_NODE=$(probe_tool node 'command -v node' "node")
T_PA11Y=$(probe_tool pa11y 'command -v pa11y' "pa11y")
T_GH=$(probe_tool gh 'command -v gh' "gh")

# --- Assemble JSON ---
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$CACHE_FILE")"

# Write to a sibling temp file then atomically rename, so a concurrent reader never sees a
# half-written cache (and a crash mid-write leaves the old cache intact).
CACHE_TMP="${CACHE_FILE}.tmp.$$"
cat > "$CACHE_TMP" <<EOF
{
  "schemaVersion": "1.0",
  "skill": "magento2-context",
  "skillVersion": "1.7.0",
  "resolvedAt": "${TIMESTAMP}",
  "cacheKey": $(json_or_null "$CACHE_KEY"),

  "vendor": $(json_or_null "$VENDOR"),
  "vendor_lower": $(json_or_null "$VENDOR_LOWER"),

  "project_root": ".",
  "magento_root": "${MAGENTO_ROOT}",
  "module_dir": "${MODULE_DIR}",
  "docs_root": ".docs",
  "edition": $(json_or_null "$EDITION"),
  "magento_version": $(json_or_null "$MAGENTO_VERSION"),

  "php_version": $(json_or_null "$PHP_VERSION"),
  "php_constraint": $(json_or_null "$PHP_CONSTRAINT"),
  "framework_constraint": $(json_or_null "$FRAMEWORK_CONSTRAINT"),

  "runner": $(runner_json),
  "runner_kind": $(json_or_null "$RUNNER_KIND"),
  "magento_cli": $(json_or_null "$MAGENTO_CLI"),
  "composer": $(json_or_null "$COMPOSER_CMD"),

  "theme": {
    "frontend": $(json_or_null "$THEME_FRONTEND"),
    "frontend_source": $(json_or_null "$THEME_FRONTEND_SRC"),
    "adminhtml": $(json_or_null "$THEME_ADMIN"),
    "adminhtml_source": $(json_or_null "$THEME_ADMIN_SRC"),
    "breeze": {
      "installed": ${BREEZE_INSTALLED},
      "active": ${BREEZE_ACTIVE},
      "parent": $(json_or_null "$BREEZE_PARENT"),
      "packages": $(json_array_from_csv "$BREEZE_PACKAGES"),
      "source": $(json_or_null "$BREEZE_SRC")
    }
  },

  "tools": {
    "phpcs": ${T_PHPCS},
    "phpstan": ${T_PHPSTAN},
    "phpunit": ${T_PHPUNIT},
    "phpmd": ${T_PHPMD},
    "rector": ${T_RECTOR},
    "psalm": ${T_PSALM},
    "php-cs-fixer": ${T_PHPCSFIXER},
    "xmllint": ${T_XMLLINT},
    "composer": ${T_COMPOSER},
    "semgrep": ${T_SEMGREP},
    "gitleaks": ${T_GITLEAKS},
    "trufflehog": ${T_TRUFFLEHOG},
    "node": ${T_NODE},
    "pa11y": ${T_PA11Y},
    "gh": ${T_GH}
  },

  "resolution_source": {
    "vendor": $(json_or_null "$VENDOR_SRC"),
    "runner": $(json_or_null "$RUNNER_SRC"),
    "magento_cli": $(json_or_null "$MAGENTO_CLI_SRC"),
    "composer": $(json_or_null "$COMPOSER_CMD_SRC"),
    "edition": $(json_or_null "$EDITION_SRC"),
    "magento_version": $(json_or_null "$MAGENTO_VERSION_SRC"),
    "php_version": $(json_or_null "$PHP_VERSION_SRC"),
    "theme.frontend": $(json_or_null "$THEME_FRONTEND_SRC"),
    "theme.adminhtml": $(json_or_null "$THEME_ADMIN_SRC")
  }
}
EOF

mv -f "$CACHE_TMP" "$CACHE_FILE"
cat "$CACHE_FILE"
