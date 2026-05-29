#!/usr/bin/env bash
# Preflight must fail when a supplied module depends on a vendor or core module that is
# present (in composer.lock or on disk) but registered as disabled (=0) in app/etc/config.php.
# This guards the v5 finding that the enabled-state check was previously local-module-only.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
mkdir -p "$WORK/src/app/etc"

cat > "$WORK/src/app/code/Acme/Probe/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Probe',__DIR__);
EOF

# Probe depends on a Magento core module (not local). Magento_Catalog is treated as
# always-known by preflight (Magento_*-prefix), so the missing-target check passes.
# But it's disabled in config.php — enabled-state should still fail.
cat > "$WORK/src/app/code/Acme/Probe/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Probe">
    <sequence>
      <module name="Magento_Catalog"/>
    </sequence>
  </module>
</config>
EOF

cat > "$WORK/src/app/etc/config.php" <<'EOF'
<?php
return [
    'modules' => [
        'Acme_Probe' => 1,
        'Magento_Catalog' => 0,
    ],
];
EOF

cd "$WORK"
set +e
MODULES="Acme_Probe" ENV=local STRICT=0 \
    RUNNER="" RUNNER_KIND="null" MAGENTO_CLI="" \
    bash "$OLDPWD/.claude/skills/magento2-deploy/scripts/preflight.sh" > preflight.json 2> preflight.err
EXIT=$?
set -e
cd "$OLDPWD"

if [ "$EXIT" = "0" ]; then
    echo "FAIL: preflight returned 0 despite disabled vendor/core dependency Magento_Catalog"
    cat "$WORK/preflight.json"
    exit 1
fi

DEP_NOTE=$(python3 -c "
import json
d = json.load(open('$WORK/preflight.json'))
for c in d['preflight']['checks']:
    if c['name'] == 'dependency-graph':
        print(c['note'])
        break
" 2>/dev/null)

if ! echo "$DEP_NOTE" | grep -q 'Magento_Catalog'; then
    echo "FAIL: dependency-graph note should call out Magento_Catalog as disabled"
    echo "$DEP_NOTE"
    exit 1
fi
if ! echo "$DEP_NOTE" | grep -qi 'disabled'; then
    echo "FAIL: dependency-graph note should mention 'disabled'"
    echo "$DEP_NOTE"
    exit 1
fi

exit 0
