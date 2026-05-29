#!/usr/bin/env bash
# Preflight must detect a cycle that includes a local module outside the supplied set.
# Scenario: MODULES=Acme_Probe. Acme_Probe -> Acme_Mid -> Acme_Probe (Mid is local).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
mkdir -p "$WORK/src/app/code/Acme/Mid/etc"
mkdir -p "$WORK/src/app/etc"

cat > "$WORK/src/app/code/Acme/Probe/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Probe',__DIR__);
EOF
cat > "$WORK/src/app/code/Acme/Probe/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Probe">
    <sequence>
      <module name="Acme_Mid"/>
    </sequence>
  </module>
</config>
EOF
cat > "$WORK/src/app/code/Acme/Mid/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Mid',__DIR__);
EOF
# Mid depends back on Probe — closing the cycle through a non-supplied local module.
cat > "$WORK/src/app/code/Acme/Mid/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Mid">
    <sequence>
      <module name="Acme_Probe"/>
    </sequence>
  </module>
</config>
EOF
# Both modules enabled — keeps the enabled-state check happy so we exercise cycle code.
cat > "$WORK/src/app/etc/config.php" <<'EOF'
<?php
return [
    'modules' => [
        'Acme_Probe' => 1,
        'Acme_Mid' => 1,
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
    echo "FAIL: preflight returned 0 despite transitive cycle Acme_Probe -> Acme_Mid -> Acme_Probe"
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

if ! echo "$DEP_NOTE" | grep -qi 'cycle'; then
    echo "FAIL: dependency-graph note should mention a cycle"
    echo "$DEP_NOTE"
    exit 1
fi

exit 0
