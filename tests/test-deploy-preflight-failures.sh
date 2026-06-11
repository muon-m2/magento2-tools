#!/usr/bin/env bash
# Deploy preflight must NOT silently green-light a release when a genuinely required tool
# (the Magento CLI, needed for setup:db:status) is unavailable. A required-but-skipped check
# still fails the run.
#
# DEP-7 refinement: PHPUnit is NOT a hard deploy blocker. A module may legitimately ship no
# unit tests, and a deploy host may legitimately lack phpunit. So when phpunit is absent the
# check is recorded as non-required + "skipped", and the overall preflight still fails here
# because the (truly required) db-status check fails with no Magento CLI.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Stage a fixture: an Acme/Probe module with the minimum files preflight expects.
mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
mkdir -p "$WORK/src/app/code/Acme/Probe/Test/Unit"
cat > "$WORK/src/app/code/Acme/Probe/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Probe',__DIR__);
EOF
cat > "$WORK/src/app/code/Acme/Probe/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Probe"/>
</config>
EOF
cat > "$WORK/src/app/code/Acme/Probe/composer.json" <<'EOF'
{ "name": "acme/probe", "type": "magento2-module", "version": "0.1.0", "autoload": { "files": ["registration.php"] } }
EOF

# Stage a context cache that declares runner_kind=null (no PHP at all in this fixture's
# eyes) so PHPUnit and DB status MUST fail under the new contract.
mkdir -p "$WORK/.claude/.cache"
cat > "$WORK/.claude/.cache/magento2-context.json" <<'EOF'
{"runner":"","runner_kind":"null","magento_cli":"","composer":"","module_dir":"src/app/code"}
EOF

cd "$WORK"

set +e
MODULES="Acme_Probe" ENV=local STRICT=0 \
    RUNNER="" RUNNER_KIND="null" MAGENTO_CLI="" \
    bash "$OLDPWD/skills/magento2-deploy/scripts/preflight.sh" > preflight.json 2> preflight.err
EXIT=$?
set -e
cd "$OLDPWD"

if [ "$EXIT" = "0" ]; then
    echo "FAIL: preflight exited 0 with no runner and no magento CLI (expected non-zero)"
    cat "$WORK/preflight.json"
    exit 1
fi

# phpunit absent ⇒ recorded as non-required + "skipped" (DEP-7); db-status must still fail
# (no Magento CLI), and the required-skipped db-status must drive the overall failure.
PHPUNIT_RESULT=$(python3 -c "
import json
d = json.load(open('$WORK/preflight.json'))
for c in d['preflight']['checks']:
    if c['name'] == 'phpunit-unit':
        print(c['result'], c['required']); break
" 2>/dev/null)
DBSTATUS_RESULT=$(python3 -c "
import json
d = json.load(open('$WORK/preflight.json'))
for c in d['preflight']['checks']:
    if c['name'] == 'db-status':
        print(c['result']); break
" 2>/dev/null)

if [ "$PHPUNIT_RESULT" != "skipped False" ]; then
    echo "FAIL: phpunit-unit result/required='$PHPUNIT_RESULT' (expected 'skipped False')"
    cat "$WORK/preflight.json"
    exit 1
fi
if [ "$DBSTATUS_RESULT" != "fail" ]; then
    echo "FAIL: db-status result='$DBSTATUS_RESULT' (expected 'fail')"
    cat "$WORK/preflight.json"
    exit 1
fi

# The preflight.json top-level passed flag must be false.
PASSED=$(python3 -c "import json; print(json.load(open('$WORK/preflight.json'))['preflight']['passed'])")
if [ "$PASSED" != "False" ] && [ "$PASSED" != "false" ]; then
    echo "FAIL: preflight.passed='$PASSED' (expected false)"
    exit 1
fi

exit 0
