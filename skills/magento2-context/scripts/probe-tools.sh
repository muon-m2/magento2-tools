#!/usr/bin/env bash
# =============================================================================
# Probe for tools that downstream magento2-* skills opportunistically use.
# Emits a small report — does not write a cache file. For a full context probe,
# use resolve-context.sh instead.
#
# Usage: ./scripts/probe-tools.sh
# =============================================================================
set -euo pipefail

report() {
    local key="$1"; local probe="$2"; local hint="$3"
    if eval "$probe" >/dev/null 2>&1; then
        printf 'AVAILABLE  %-15s %s\n' "$key" "$hint"
    else
        printf 'MISSING    %-15s %s\n' "$key" "$hint"
    fi
}

echo "Tool probe — magento2-context"
echo ""

echo "== Project-local (vendor/bin) =="
report phpcs        '[ -x vendor/bin/phpcs ]'        'vendor/bin/phpcs --standard=Magento2'
report phpstan      '[ -x vendor/bin/phpstan ]'      'vendor/bin/phpstan analyse'
report phpunit      '[ -x vendor/bin/phpunit ]'      'vendor/bin/phpunit'
report phpmd        '[ -x vendor/bin/phpmd ]'        'vendor/bin/phpmd analyze'
report rector       '[ -x vendor/bin/rector ]'       'vendor/bin/rector process'
report psalm        '[ -x vendor/bin/psalm ]'        'vendor/bin/psalm'
report php-cs-fixer '[ -x vendor/bin/php-cs-fixer ]' 'vendor/bin/php-cs-fixer fix'

echo ""
echo "== System (PATH) =="
report php          'command -v php'         'php -l <file>'
report xmllint      'command -v xmllint'     'xmllint --noout <file>'
report composer     'command -v composer'    'composer validate'
report node         'command -v node'        'node --check'
report semgrep      'command -v semgrep'     'semgrep scan'
report gitleaks     'command -v gitleaks'    'gitleaks detect'
report trufflehog   'command -v trufflehog'  'trufflehog filesystem'
report pa11y        'command -v pa11y'       'pa11y http://...'
report gh           'command -v gh'          'gh pr create'
report docker       'command -v docker'      'docker compose ps'

echo ""
echo "== Magento CLI =="
if [[ -f bin/magento ]]; then
    echo "AVAILABLE  bin/magento     bin/magento setup:upgrade"
elif [[ -f src/bin/magento ]]; then
    echo "AVAILABLE  src/bin/magento src/bin/magento setup:upgrade (Magento root = src/)"
else
    echo "MISSING    bin/magento     no Magento CLI in this tree"
fi
