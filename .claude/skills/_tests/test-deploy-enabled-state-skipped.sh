#!/usr/bin/env bash
# When app/etc/config.php is missing, enabled-state verification is skipped — but the
# saved JSON must surface that fact via a `dependency-enabled-state` check with
# result=skipped. The dependency-graph check itself still passes.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
mkdir -p "$WORK/src/app/code/Acme/Dep/etc"
# No src/app/etc/config.php on purpose.

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

cd "$WORK"
set +e
MODULES="Acme_Probe" ENV=local STRICT=0 \
    RUNNER="" RUNNER_KIND="null" MAGENTO_CLI="" \
    bash "$OLDPWD/.claude/skills/magento2-deploy/scripts/preflight.sh" > preflight.json 2> preflight.err
set -e
cd "$OLDPWD"

ENABLED_STATE_RESULT=$(python3 -c "
import json
d = json.load(open('$WORK/preflight.json'))
for c in d['preflight']['checks']:
    if c['name'] == 'dependency-enabled-state':
        print(c['result'])
        print(c.get('note', ''))
        break
" 2>/dev/null)

if [ -z "$ENABLED_STATE_RESULT" ]; then
    echo "FAIL: preflight JSON has no dependency-enabled-state check"
    cat "$WORK/preflight.json"
    exit 1
fi

if ! echo "$ENABLED_STATE_RESULT" | grep -q '^skipped'; then
    echo "FAIL: expected dependency-enabled-state result=skipped when config.php is missing"
    echo "$ENABLED_STATE_RESULT"
    exit 1
fi
if ! echo "$ENABLED_STATE_RESULT" | grep -q 'config.php is missing'; then
    echo "FAIL: skip note should explain why (config.php is missing)"
    echo "$ENABLED_STATE_RESULT"
    exit 1
fi

exit 0
