#!/usr/bin/env bash
# Preflight must fail when a module declares a <sequence> dependency on a module that
# is neither on disk nor in composer.lock.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Acme/Probe with a <sequence> referencing the non-existent Acme_Missing.
mkdir -p "$WORK/src/app/code/Acme/Probe/etc"
cat > "$WORK/src/app/code/Acme/Probe/registration.php" <<'EOF'
<?php declare(strict_types=1); use Magento\Framework\Component\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'Acme_Probe',__DIR__);
EOF
cat > "$WORK/src/app/code/Acme/Probe/etc/module.xml" <<'EOF'
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
  <module name="Acme_Probe">
    <sequence>
      <module name="Acme_Missing"/>
    </sequence>
  </module>
</config>
EOF

mkdir -p "$WORK/.claude/.cache"
cat > "$WORK/.claude/.cache/magento2-context.json" <<'EOF'
{"runner":"","runner_kind":"null","magento_cli":"","composer":"","module_dir":"src/app/code"}
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
    echo "FAIL: preflight returned 0 despite missing <sequence> target"
    cat "$WORK/preflight.json"
    exit 1
fi

# Locate the dependency-graph check and confirm it failed mentioning the missing module.
DEP_RESULT=$(python3 -c "
import json
d = json.load(open('$WORK/preflight.json'))
for c in d['preflight']['checks']:
    if c['name'] == 'dependency-graph':
        print(c['result'])
        print(c['note'])
        break
" 2>/dev/null)

if ! echo "$DEP_RESULT" | grep -q 'fail'; then
    echo "FAIL: dependency-graph result should be 'fail'"
    echo "$DEP_RESULT"
    exit 1
fi
if ! echo "$DEP_RESULT" | grep -q 'Acme_Missing'; then
    echo "FAIL: dependency-graph note should mention the missing module Acme_Missing"
    echo "$DEP_RESULT"
    exit 1
fi

exit 0
