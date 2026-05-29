#!/usr/bin/env bash
# Preflight must fail when a supplied module depends on an external local module that
# is present on disk but disabled in app/etc/config.php.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Acme/Probe depends on Acme/Dep. Both are local. Acme/Dep is registered in config.php
# with value 0 (disabled). Acme/Probe is the only supplied module.
mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
mkdir -p "$WORK/src/app/code/Acme/Dep/etc"
mkdir -p "$WORK/src/app/etc"

cat > "$WORK/src/app/code/Acme/Probe/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Probe',__DIR__);
EOF
cat > "$WORK/src/app/code/Acme/Probe/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Probe">
    <sequence>
      <module name="Acme_Dep"/>
    </sequence>
  </module>
</config>
EOF
cat > "$WORK/src/app/code/Acme/Dep/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Dep',__DIR__);
EOF
cat > "$WORK/src/app/code/Acme/Dep/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Dep"/>
</config>
EOF
cat > "$WORK/src/app/etc/config.php" <<'EOF'
<?php
return [
    'modules' => [
        'Acme_Probe' => 1,
        'Acme_Dep' => 0,
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
    echo "FAIL: preflight returned 0 despite disabled external sequence target"
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

if ! echo "$DEP_NOTE" | grep -q 'Acme_Dep'; then
    echo "FAIL: dependency-graph note should call out Acme_Dep as disabled"
    echo "$DEP_NOTE"
    exit 1
fi
if ! echo "$DEP_NOTE" | grep -qi 'disabled'; then
    echo "FAIL: dependency-graph note should mention 'disabled'"
    echo "$DEP_NOTE"
    exit 1
fi

exit 0
