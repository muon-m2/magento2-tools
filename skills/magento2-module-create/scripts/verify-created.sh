#!/usr/bin/env bash
# =============================================================================
# Verify a newly created Magento 2 module against the creation checklist.
#
# Usage: ./scripts/verify-created.sh src/app/code/{Vendor}/{ModuleName}
#
# Exit codes:
#   0 — all checks pass (PASS or WARN only)
#   1 — one or more FAIL items found
#   2 — bad arguments
# =============================================================================
set -euo pipefail

module_path="${1:-}"

if [[ -z "$module_path" || ! -d "$module_path" ]]; then
    echo "Usage: $0 <module-path>" >&2
    exit 2
fi

PASS=0
WARN=0
FAIL=0

# Prefer containerized PHP/Composer when a running php service is available.
# Falls back to host binaries when Docker is unavailable or the container is not running.
PHP_CMD="php"
COMPOSER_CMD="composer"
if command -v docker >/dev/null 2>&1 && \
   docker compose ps php 2>/dev/null | grep -q "running"; then
    PHP_CMD="docker compose exec -T -u magento php php"
    COMPOSER_CMD="docker compose exec -T -u magento php composer"
fi

ok()   { PASS=$((PASS + 1)); printf "  ✓  %s\n" "$1"; }
warn() { WARN=$((WARN + 1)); printf "  ⚠  %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  ✗  %s\n" "$1"; }

echo "Verifying: $module_path"
echo ""

# =============================================================================
# Category 1 — Required files
# =============================================================================
echo "== Category 1: Required files =="

for f in registration.php composer.json etc/module.xml etc/di.xml README.md CHANGELOG.md; do
    if [[ -f "${module_path}/${f}" ]]; then
        ok "$f"
    else
        fail "$f missing"
    fi
done

# LICENSE file (Marketplace/EQP blocker) — must match the composer `license` field
if [[ -f "${module_path}/LICENSE.txt" || -f "${module_path}/LICENSE" ]]; then
    ok "LICENSE file present"
else
    fail "LICENSE file missing — add LICENSE.txt matching the composer license field"
fi

# .gitignore (Marketplace info-level recommendation)
if [[ -f "${module_path}/.gitignore" ]]; then
    ok ".gitignore present"
else
    warn ".gitignore missing — add one (vendor/, node_modules/, *.log, .DS_Store)"
fi

# Forbidden directories
if [[ -d "${module_path}/Helper" ]]; then
    fail "Helper/ directory present — use Service/ or ViewModel/ instead"
else
    ok "No Helper/ directory"
fi

# Forbidden legacy schema files
for f in Setup/InstallSchema.php Setup/UpgradeSchema.php; do
    if [[ -f "${module_path}/${f}" ]]; then
        fail "${f} present — use declarative schema (etc/db_schema.xml)"
    fi
done

# db_schema whitelist
if [[ -f "${module_path}/etc/db_schema.xml" ]]; then
    if [[ -f "${module_path}/etc/db_schema_whitelist.json" ]]; then
        ok "db_schema_whitelist.json present"
    else
        fail "etc/db_schema.xml present but etc/db_schema_whitelist.json missing"
    fi
fi

# =============================================================================
# Category 2 — Registration & Declaration
# =============================================================================
echo ""
echo "== Category 2: Registration & Declaration =="

# module.xml: no setup_version
if [[ -f "${module_path}/etc/module.xml" ]]; then
    if grep -q "setup_version" "${module_path}/etc/module.xml"; then
        fail "etc/module.xml contains setup_version — remove it"
    else
        ok "No setup_version in etc/module.xml"
    fi
fi

# composer.json: key fields
if [[ -f "${module_path}/composer.json" ]]; then
    if grep -q '"type".*"magento2-module"' "${module_path}/composer.json"; then
        ok "composer.json type=magento2-module"
    else
        fail "composer.json missing or incorrect type (expected magento2-module)"
    fi

    if grep -q '"php"' "${module_path}/composer.json"; then
        ok "composer.json php constraint present"
    else
        fail "composer.json missing php constraint (derive from src/composer.json)"
    fi

    if grep -q '"magento/framework"' "${module_path}/composer.json"; then
        ok "composer.json magento/framework constraint present"
    else
        fail "composer.json missing magento/framework constraint (derive from src/composer.json)"
    fi

    if grep -q '"version"' "${module_path}/composer.json"; then
        ok "composer.json version field present"
    else
        fail "composer.json missing version field"
    fi

    if grep -q '"license"' "${module_path}/composer.json"; then
        ok "composer.json license field present"
    else
        fail "composer.json missing license field"
    fi

    if grep -q '"authors"' "${module_path}/composer.json"; then
        ok "composer.json authors field present"
    else
        warn "composer.json missing authors field (Marketplace warning)"
    fi

    if grep -q '"psr-4"' "${module_path}/composer.json" && \
       ! grep -q '"psr-0"' "${module_path}/composer.json"; then
        ok "composer.json uses PSR-4 autoload"
    else
        fail "composer.json missing PSR-4 autoload or uses PSR-0"
    fi

    if grep -q '"files".*\[' "${module_path}/composer.json" && \
       grep -q '"registration.php"' "${module_path}/composer.json"; then
        ok "composer.json autoload.files includes registration.php"
    else
        warn "composer.json autoload.files may be missing registration.php"
    fi

    if grep -q '"\*"' "${module_path}/composer.json"; then
        fail "composer.json contains wildcard (*) version constraint"
    else
        ok "No wildcard version constraints"
    fi
fi

# =============================================================================
# Category 3 — Forbidden naming patterns
# =============================================================================
echo ""
echo "== Category 3: Naming patterns =="

# Grep for Helper/Manager class names in production PHP
bad_names=$(grep -RlnE --include='*.php' \
    '^(abstract |final |readonly )*(class) [A-Za-z]*(Helper|Manager)' \
    "${module_path}" 2>/dev/null | grep -v '/Test/' || true)

if [[ -n "$bad_names" ]]; then
    fail "Classes named *Helper* or *Manager* found: $(echo "$bad_names" | tr '\n' ' ')"
else
    ok "No Helper/Manager class names"
fi

# =============================================================================
# Category 4 — PHP coding standards
# =============================================================================
echo ""
echo "== Category 4: PHP coding standards =="

# PHP syntax check (uses containerized PHP when available, falls back to host)
if $PHP_CMD -v >/dev/null 2>&1; then
    syntax_errors=0
    while IFS= read -r -d '' file; do
        result=$($PHP_CMD -l "$file" 2>&1 || true)
        if ! echo "$result" | grep -q "No syntax errors"; then
            fail "PHP syntax error: ${file#"$module_path/"}"
            printf "     %s\n" "$result"
            syntax_errors=$((syntax_errors + 1))
        fi
    done < <(find "$module_path" -type f -name '*.php' -print0)
    [[ $syntax_errors -eq 0 ]] && ok "All PHP files pass syntax check"
else
    warn "php not available — PHP syntax check skipped"
fi

# declare(strict_types=1) in every non-test PHP file
strict_missing=0
while IFS= read -r -d '' file; do
    if ! grep -q "declare(strict_types=1)" "$file"; then
        fail "Missing declare(strict_types=1): ${file#"$module_path/"}"
        strict_missing=$((strict_missing + 1))
    fi
done < <(find "$module_path" -type f -name '*.php' -not -path '*/Test/*' -print0)
[[ $strict_missing -eq 0 ]] && ok "declare(strict_types=1) in all production PHP files"

# Copyright/license header in every PHP file (applied by the shared add-license-headers.sh).
# A miss here means the stamp step did not run — re-run it before reporting done.
header_missing=0
while IFS= read -r -d '' file; do
    if ! grep -qF "See LICENSE.txt for license details." "$file"; then
        fail "Missing copyright header: ${file#"$module_path/"} (run magento2-context/scripts/add-license-headers.sh)"
        header_missing=$((header_missing + 1))
    fi
done < <(find "$module_path" -type f -name '*.php' -print0)
[[ $header_missing -eq 0 ]] && ok "Copyright header present in all PHP files"

# Forbidden constructs in production PHP.
# The final alternative targets the @ error-suppression operator, which always precedes a
# call expression (e.g. @file_get_contents(...), @unlink(...)). Matching `@<ident>(` avoids
# the previous `@[a-zA-Z_]` pattern that flagged every PHPDoc tag (@param, @return, @api)
# and made every compliant module fail (MC-1).
forbidden_pattern='ObjectManager::getInstance\(\)|die\(|exit\(|var_dump\(|eval\(|print_r\(|\becho\b|\bprint\b|@[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\('
forbidden_hits=$(grep -RlnE --include='*.php' "$forbidden_pattern" \
    "$module_path" 2>/dev/null | grep -v '/Test/' || true)
if [[ -n "$forbidden_hits" ]]; then
    fail "Forbidden constructs found: $(echo "$forbidden_hits" | tr '\n' ' ')"
else
    ok "No forbidden constructs (ObjectManager, die, exit, var_dump, eval, echo, print, @ operator)"
fi

# =============================================================================
# Category 5 — PHPDoc: @api on interfaces in Api/
# =============================================================================
echo ""
echo "== Category 5: PHPDoc =="

if [[ -d "${module_path}/Api" ]]; then
    api_missing_tag=0
    while IFS= read -r -d '' file; do
        if ! grep -q "@api" "$file"; then
            warn "Missing @api annotation: ${file#"$module_path/"}"
            api_missing_tag=$((api_missing_tag + 1))
        fi
    done < <(find "${module_path}/Api" -type f -name '*.php' \
        ! -path '*/Test/*' -print0 2>/dev/null)
    [[ $api_missing_tag -eq 0 ]] && ok "@api present in all Api/ interfaces"
else
    ok "No Api/ directory (not required for this surface set)"
fi

# =============================================================================
# Category 7 — Security patterns
# =============================================================================
echo ""
echo "== Category 7: Security =="

# Deprecated $block->escape* in templates
if find "$module_path" -name '*.phtml' | grep -q .; then
    block_escape=$(grep -RlnE --include='*.phtml' \
        '\$block->escape' "$module_path" 2>/dev/null || true)
    if [[ -n "$block_escape" ]]; then
        fail "Deprecated \$block->escape*() in: $(echo "$block_escape" | tr '\n' ' ')"
    else
        ok "No deprecated \$block->escape*() in templates"
    fi
fi

# Raw SQL patterns
raw_sql=$(grep -RlnE --include='*.php' \
    'SELECT .* FROM|INSERT INTO|UPDATE .* SET|DELETE FROM' \
    "$module_path" 2>/dev/null | grep -v '/Test/' || true)
if [[ -n "$raw_sql" ]]; then
    warn "Possible raw SQL in: $(echo "$raw_sql" | tr '\n' ' ') — verify parameterized queries"
else
    ok "No obvious raw SQL strings"
fi

# =============================================================================
# Category 8 — ACL check for admin controllers
# =============================================================================
echo ""
echo "== Category 8: ACL =="

if [[ -d "${module_path}/Controller/Adminhtml" ]]; then
    if [[ -f "${module_path}/etc/acl.xml" ]]; then
        ok "etc/acl.xml present for admin controllers"
    else
        fail "Controller/Adminhtml/ present but etc/acl.xml missing"
    fi

    admin_missing_resource=0
    while IFS= read -r -d '' file; do
        if ! grep -q "ADMIN_RESOURCE" "$file"; then
            fail "Missing ADMIN_RESOURCE constant: ${file#"$module_path/"}"
            admin_missing_resource=$((admin_missing_resource + 1))
        fi
    done < <(find "${module_path}/Controller/Adminhtml" -name '*.php' -print0 2>/dev/null)
    [[ $admin_missing_resource -eq 0 ]] && ok "ADMIN_RESOURCE declared in all admin controllers"
else
    ok "No admin controllers (ACL check not required)"
fi

# =============================================================================
# Category 9 — i18n: CSV present when UI surface declared
# =============================================================================
echo ""
echo "== Category 9: i18n =="

if [[ -d "${module_path}/view/adminhtml" || -d "${module_path}/view/frontend" ]]; then
    if [[ -f "${module_path}/i18n/en_US.csv" ]]; then
        ok "i18n/en_US.csv present for UI surface"
    else
        fail "UI surface declared but i18n/en_US.csv missing"
    fi
else
    ok "No UI surface (i18n not required)"
fi

# =============================================================================
# Category 10 — Testing: test classes for Service/ and Model/Repository
# =============================================================================
echo ""
echo "== Category 10: Testing =="

if [[ -d "${module_path}/Service" ]]; then
    service_missing=0
    while IFS= read -r -d '' src; do
        basename="${src##*/}"
        testname="${basename%.php}Test.php"
        if ! find "${module_path}/Test/Unit" -name "$testname" -print -quit 2>/dev/null | grep -q .; then
            warn "No unit test found for ${src#"$module_path/"} (expected Test/Unit/**/${testname})"
            service_missing=$((service_missing + 1))
        fi
    done < <(find "${module_path}/Service" -name '*.php' -print0 2>/dev/null)
    [[ $service_missing -eq 0 ]] && ok "Unit tests found for all Service/ classes"
else
    ok "No Service/ directory (unit test check skipped)"
fi

if [[ -d "${module_path}/Model" ]]; then
    repo_missing=0
    while IFS= read -r -d '' src; do
        basename="${src##*/}"
        testname="${basename%.php}Test.php"
        if ! find "${module_path}/Test/Unit" -name "$testname" -print -quit 2>/dev/null | grep -q .; then
            warn "No unit test found for ${src#"$module_path/"} (expected Test/Unit/**/${testname})"
            repo_missing=$((repo_missing + 1))
        fi
    done < <(find "${module_path}/Model" -maxdepth 1 -name '*Repository.php' -print0 2>/dev/null)
    [[ $repo_missing -eq 0 ]] && ok "Unit tests found for all Model/*Repository.php classes"
fi

# MFTF functional coverage when a UI surface is present (Marketplace weighs this).
if [[ -d "${module_path}/view/adminhtml" || -d "${module_path}/view/frontend" ]]; then
    if find "${module_path}/Test/Mftf" -name '*.xml' -print -quit 2>/dev/null | grep -q .; then
        ok "MFTF test present for UI surface"
    else
        warn "UI surface declared but no MFTF test under Test/Mftf/ (Marketplace functional coverage)"
    fi
fi

# =============================================================================
# Category 11 — Admin configuration completeness
# =============================================================================
echo ""
echo "== Category 11: Admin Configuration =="

if [[ -f "${module_path}/etc/adminhtml/system.xml" ]]; then
    if [[ -f "${module_path}/etc/config.xml" ]]; then
        ok "etc/config.xml present alongside system.xml"
    else
        fail "etc/adminhtml/system.xml present but etc/config.xml missing"
    fi

    # Every <section> in system.xml must have a <resource> element
    # grep -c prints the count (0 on no match) but exits 1 on no match; `|| true` keeps the
    # single "0" line instead of `|| echo 0` appending a second "0" (which broke the
    # `-gt`/`-lt` arithmetic below on a "0\n0" value).
    section_count=$(grep -c '<section ' "${module_path}/etc/adminhtml/system.xml" 2>/dev/null || true)
    resource_count=$(grep -c '<resource>' "${module_path}/etc/adminhtml/system.xml" 2>/dev/null || true)
    section_count=${section_count:-0}
    resource_count=${resource_count:-0}
    if [[ "$section_count" -gt 0 && "$resource_count" -lt "$section_count" ]]; then
        fail "system.xml: ${section_count} <section> element(s) but only ${resource_count} <resource> element(s) — every section needs ACL protection"
    else
        ok "system.xml: all sections have <resource> ACL protection"
    fi
else
    ok "No system.xml (admin config check not required)"
fi

# =============================================================================
# XML well-formedness
# =============================================================================
echo ""
echo "== XML well-formedness =="

if command -v xmllint >/dev/null 2>&1; then
    xml_errors=0
    while IFS= read -r -d '' file; do
        result=$(xmllint --noout "$file" 2>&1 || true)
        if [[ -n "$result" ]]; then
            fail "XML error in ${file#"$module_path/"}: $result"
            xml_errors=$((xml_errors + 1))
        fi
    done < <(find "${module_path}/etc" -name '*.xml' -print0 2>/dev/null)
    [[ $xml_errors -eq 0 ]] && ok "All XML files well-formed"
else
    warn "xmllint not available — XML well-formedness check skipped"
fi

# =============================================================================
# Composer validate
# =============================================================================
echo ""
echo "== Composer validate =="

if [[ -f "${module_path}/composer.json" ]]; then
    if $COMPOSER_CMD --version >/dev/null 2>&1; then
        result=$($COMPOSER_CMD validate --no-check-publish "${module_path}/composer.json" 2>&1 || true)
        if echo "$result" | grep -qi "is valid"; then
            ok "composer validate passed"
        else
            fail "composer validate failed: $result"
        fi
    elif $PHP_CMD -v >/dev/null 2>&1; then
        if $PHP_CMD -r "json_decode(file_get_contents('${module_path}/composer.json'), true, 512, JSON_THROW_ON_ERROR);" 2>/dev/null; then
            ok "composer.json parses as valid JSON (composer not available for full validation)"
        else
            fail "composer.json is not valid JSON"
        fi
    else
        warn "composer and php not available — composer.json validation skipped"
    fi
fi

# =============================================================================
# Optional quality tools
# =============================================================================
echo ""
echo "== Optional quality tools =="

if [[ -f "vendor/bin/phpcs" ]]; then
    echo "  Running phpcs (Magento2 standard)..."
    phpcs_out=$(vendor/bin/phpcs --standard=Magento2 --report=summary \
        "$module_path" 2>&1 || true)
    if echo "$phpcs_out" | grep -q "ERROR"; then
        warn "phpcs errors found — run vendor/bin/phpcs --standard=Magento2 ${module_path} for details"
    else
        ok "phpcs Magento2 standard — no errors"
    fi
else
    warn "vendor/bin/phpcs not available — PHPCS check skipped"
fi

if [[ -f "vendor/bin/phpstan" ]]; then
    echo "  Running phpstan..."
    phpstan_out=$(vendor/bin/phpstan analyse --error-format=table \
        "$module_path" 2>&1 || true)
    if echo "$phpstan_out" | grep -qE "Error|error"; then
        warn "phpstan errors found — run vendor/bin/phpstan analyse ${module_path} for details"
    else
        ok "phpstan analysis passed"
    fi
else
    warn "vendor/bin/phpstan not available — PHPStan check skipped"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================"
printf "  PASS: %-4d  WARN: %-4d  FAIL: %d\n" "$PASS" "$WARN" "$FAIL"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "  RESULT: FAIL — fix all ✗ items before deploying."
    echo "  Run the magento2-module-review skill for full PHPCS + PHPStan + unit test results."
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo "  RESULT: WARN — review ⚠ items before release."
    echo "  Run the magento2-module-review skill on {Vendor}/{ModuleName} to verify all 12 categories."
    exit 0
else
    echo ""
    echo "  RESULT: PASS — module is compliant."
    echo "  Run the magento2-deploy skill to enable and deploy, then magento2-module-review to confirm."
    exit 0
fi
