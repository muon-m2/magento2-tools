#!/usr/bin/env bash
# build-findings.sh — aggregate security scanner outputs into one findings document
# (skill-labelled as security, output kind "security"). Thin wrapper over
# the shared engine context/scripts/findings-lib.sh.
#
# Inputs (env vars):
#   TARGET_MODULE       e.g. "Acme_OrderS3Export" or "site"
#   TARGET_PATH         e.g. "src/app/code/Acme/OrderS3Export" or "."
#   SCOPE               "module" | "site" | "vendor"  (default: module)
#   COMPOSER_LOCK       default: src/composer.lock
#   SCAN_ROOT           default: src/app/code  (cross-module scan)
#   SECRET_ROOT         default: SCAN_ROOT without /code, i.e. the app/ tree (secret scan,
#                       so app/etc/env.php is covered)
#   DOCS_ROOT           default: .docs — project-root artifact dir ({ctx.docs_root}).
#                       Pass an absolute or project-root path so an in-`src/` cwd cannot
#                       redirect output into the Magento tree. See context/SKILL.md.
#   OUTPUT_DIR          default: {DOCS_ROOT}/audits
#   SKILL_VERSION       default: 2.1.0
#   RUNNER              Runner prefix for {MAGENTO_ROOT}/vendor/bin/patch-status, e.g.
#                       "docker compose exec -T -u magento php" (default: "" — run on the
#                       host). Forwarded to advisory-scan.sh via the environment.
#   PATCH_STATUS        "0" disables consulting vendor/bin/patch-status (default: "1";
#                       legacy alias CVE_PATCH_STATUS is honoured).
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-security-{YYYY-MM-DD}.json (module scope) or
#   {OUTPUT_DIR}/security-{SCOPE}-{YYYY-MM-DD}.json (site/vendor scope) + .sarif.
#   Stdout echoes the JSON.

set -uo pipefail

SCOPE="${SCOPE:-module}"
COMPOSER_LOCK="${COMPOSER_LOCK:-$([[ -f composer.lock ]] && echo composer.lock || echo src/composer.lock)}"
SCAN_ROOT="${SCAN_ROOT:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
# Secret scanning needs to reach app/etc/env.php (the crypt key), which sits OUTSIDE app/code.
SECRET_ROOT="${SECRET_ROOT:-${SCAN_ROOT%/code}}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
SKILL_VERSION="${SKILL_VERSION:-2.1.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"

findings_init
findings_scan advisory-scan     "${SCRIPT_DIR}/advisory-scan.sh" "$COMPOSER_LOCK" || true
findings_scan secret-scan       "${SCRIPT_DIR}/secret-scan.sh" "$SECRET_ROOT"     || true
findings_scan cross-module-scan "${SCRIPT_DIR}/cross-module-scan.sh" "$SCAN_ROOT" || true

SKILL_NAME="security"
OUTPUT_KIND="security"
BASENAME_KIND="security"
findings_emit
