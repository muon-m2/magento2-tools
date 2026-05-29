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
json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g' | tr -d '\n'; }
json_or_null() { if [[ -z "$1" || "$1" == "null" ]]; then printf 'null'; else printf '"%s"' "$(json_str "$1")"; fi; }

# --- Cache key (composer.lock + composer.json + CLAUDE.md) ---
hash_file() {
    if [[ -f "$1" ]]; then sha256sum "$1" | cut -d' ' -f1; else echo "absent"; fi
}
LOCK_FILE=""
if [[ -f "composer.lock" ]]; then LOCK_FILE="composer.lock"
elif [[ -f "src/composer.lock" ]]; then LOCK_FILE="src/composer.lock"; fi
JSON_FILE=""
if [[ -f "composer.json" ]]; then JSON_FILE="composer.json"
elif [[ -f "src/composer.json" ]]; then JSON_FILE="src/composer.json"; fi
CLAUDE_FILE=""
[[ -f "CLAUDE.md" ]] && CLAUDE_FILE="CLAUDE.md"

CACHE_KEY="lock:$(hash_file "${LOCK_FILE:-/dev/null}");json:$(hash_file "${JSON_FILE:-/dev/null}");claude:$(hash_file "${CLAUDE_FILE:-/dev/null}")"

# --- Cache check ---
if [[ "$USE_CACHE" == "true" && -f "$CACHE_FILE" ]]; then
    cached_key=$(jget_php "$CACHE_FILE" "cacheKey")
    if [[ -n "$cached_key" && "$cached_key" == "$CACHE_KEY" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# --- Vendor resolution ---
VENDOR=""
VENDOR_SRC=""

# 1. CLAUDE.md
if [[ -f "CLAUDE.md" ]]; then
    raw=$(grep -E '^[[:space:]]*Vendor prefix[[:space:]]*:' CLAUDE.md | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/\*\*//g; s/`//g' | xargs || echo "")
    if [[ -n "$raw" && "$raw" =~ ^[A-Za-z]+$ ]]; then
        VENDOR=$(printf '%s' "$raw" | sed -E 's/^./\U&/')
        VENDOR_SRC="CLAUDE.md:Vendor prefix"
    fi
fi

# 2. src/app/code inspection
if [[ -z "$VENDOR" && -d "src/app/code" ]]; then
    candidates=()
    while IFS= read -r dir; do
        name=$(basename "$dir")
        [[ "$name" != "Magento" ]] && candidates+=("$name")
    done < <(find src/app/code -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    if [[ ${#candidates[@]} -eq 1 ]]; then
        VENDOR="${candidates[0]}"
        VENDOR_SRC="src/app/code/${VENDOR}/ (single non-Magento dir)"
    fi
fi

VENDOR_LOWER=""
if [[ -n "$VENDOR" ]]; then
    VENDOR_LOWER=$(printf '%s' "$VENDOR" | tr '[:upper:]' '[:lower:]')
fi

# --- Magento root ---
MAGENTO_ROOT="src"
[[ -f "bin/magento" ]] && MAGENTO_ROOT="."
MODULE_DIR="${MAGENTO_ROOT}/app/code"
[[ "$MAGENTO_ROOT" == "." ]] && MODULE_DIR="app/code"

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

# Docker compose probe
if [[ "$RUNNER_KIND" == "null" ]] && command -v docker >/dev/null 2>&1; then
    if docker compose ps --services --filter status=running 2>/dev/null | grep -qx "php"; then
        RUNNER="docker compose exec -T -u ${DOCKER_USER} php"
        RUNNER_KIND="docker-compose"
        RUNNER_SRC="docker compose ps probe"
    fi
fi

# Bare docker exec for a known container
if [[ "$RUNNER_KIND" == "null" ]] && command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '(battlefield-php|magento.*php|m2.*php)'; then
        container=$(docker ps --format '{{.Names}}' | grep -E '(battlefield-php|magento.*php|m2.*php)' | head -1)
        RUNNER="docker exec -i ${container}"
        RUNNER_KIND="docker-exec"
        RUNNER_SRC="docker ps probe (${container})"
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
    if [[ -f "${MAGENTO_ROOT}/bin/magento" || -f "bin/magento" ]]; then
        # ${RUNNER} is empty for bare mode, so leading-space collapses naturally.
        MAGENTO_CLI="$(echo "${RUNNER} bin/magento" | sed 's/^ //')"
        MAGENTO_CLI_SRC="{runner} + bin/magento exists"
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
    if [[ -n "$ent" ]]; then
        EDITION="commerce"
        MAGENTO_VERSION=$(printf '%s' "$ent" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:magento/product-enterprise-edition"
        MAGENTO_VERSION_SRC="$EDITION_SRC"
    elif [[ -n "$com" ]]; then
        EDITION="open-source"
        MAGENTO_VERSION=$(printf '%s' "$com" | sed -E 's/[~^>=<* ]//g' | head -c 40)
        EDITION_SRC="${COMPOSER_JSON}:magento/product-community-edition"
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
    active=$(php -r "
        \$d = include '$CONFIG_PHP';
        \$themes = \$d['themes'] ?? [];
        \$out = [];
        foreach (\$themes as \$code => \$row) {
            \$area = \$row['area'] ?? '';
            \$path = \$row['theme_path'] ?? '';
            if (\$area === 'frontend' && !isset(\$out['frontend'])) { \$out['frontend'] = \$path; }
            if (\$area === 'adminhtml' && !isset(\$out['adminhtml'])) { \$out['adminhtml'] = \$path; }
        }
        echo (\$out['frontend'] ?? '') . '|' . (\$out['adminhtml'] ?? '');
    " 2>/dev/null || echo "|")
    fe="${active%%|*}"; ah="${active##*|}"
    if [[ -n "$fe" ]]; then
        THEME_FRONTEND="$fe"
        THEME_FRONTEND_SRC="${CONFIG_PHP}:themes[].area=frontend"
    fi
    if [[ -n "$ah" ]]; then
        THEME_ADMIN="$ah"
        THEME_ADMIN_SRC="${CONFIG_PHP}:themes[].area=adminhtml"
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

# --- Tools ---
probe_tool() {
    local key="$1"; local probe="$2"; local resolved="$3"
    if eval "$probe" >/dev/null 2>&1; then
        printf '"%s"' "$resolved"
    else
        printf 'null'
    fi
}

T_PHPCS=$(probe_tool phpcs '[ -x vendor/bin/phpcs ]' "vendor/bin/phpcs")
T_PHPSTAN=$(probe_tool phpstan '[ -x vendor/bin/phpstan ]' "vendor/bin/phpstan")
T_PHPUNIT=$(probe_tool phpunit '[ -x vendor/bin/phpunit ]' "vendor/bin/phpunit")
T_PHPMD=$(probe_tool phpmd '[ -x vendor/bin/phpmd ]' "vendor/bin/phpmd")
T_RECTOR=$(probe_tool rector '[ -x vendor/bin/rector ]' "vendor/bin/rector")
T_PSALM=$(probe_tool psalm '[ -x vendor/bin/psalm ]' "vendor/bin/psalm")
T_PHPCSFIXER=$(probe_tool php-cs-fixer '[ -x vendor/bin/php-cs-fixer ]' "vendor/bin/php-cs-fixer")
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

cat > "$CACHE_FILE" <<EOF
{
  "schemaVersion": "1.0",
  "skill": "magento2-context",
  "skillVersion": "1.1.0",
  "resolvedAt": "${TIMESTAMP}",
  "cacheKey": $(json_or_null "$CACHE_KEY"),

  "vendor": $(json_or_null "$VENDOR"),
  "vendor_lower": $(json_or_null "$VENDOR_LOWER"),

  "magento_root": "${MAGENTO_ROOT}",
  "module_dir": "${MODULE_DIR}",
  "edition": $(json_or_null "$EDITION"),
  "magento_version": $(json_or_null "$MAGENTO_VERSION"),

  "php_version": $(json_or_null "$PHP_VERSION"),
  "php_constraint": $(json_or_null "$PHP_CONSTRAINT"),
  "framework_constraint": $(json_or_null "$FRAMEWORK_CONSTRAINT"),

  "runner": $(json_or_null "$RUNNER"),
  "runner_kind": $(json_or_null "$RUNNER_KIND"),
  "magento_cli": $(json_or_null "$MAGENTO_CLI"),
  "composer": $(json_or_null "$COMPOSER_CMD"),

  "theme": {
    "frontend": $(json_or_null "$THEME_FRONTEND"),
    "frontend_source": $(json_or_null "$THEME_FRONTEND_SRC"),
    "adminhtml": $(json_or_null "$THEME_ADMIN"),
    "adminhtml_source": $(json_or_null "$THEME_ADMIN_SRC")
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

cat "$CACHE_FILE"
