#!/usr/bin/env bash
# Preflight must find a module wherever Composer or a working copy put it, not only under app/code —
# both a SUPPLIED module and a module it <sequence>s.
#
# Regression test for two lookups that only knew app/code:
#   1. module-registration and dependency-graph looked for the supplied modules only at
#      ${MODULE_DIR}/<Vendor>/<Module>. A module installed with Composer (vendor/<vendor>/<package>),
#      or worked on from a dev-packages/<package> clone, failed both as "missing …/registration.php",
#      so it could never pass `deploy --validate-only` — and therefore never `release` validation.
#   2. A <sequence> target outside app/code counted as present only when composer.lock carried
#      extra.magento.module-name (almost no package does) or a package named exactly
#      "vendor/modulename". Conventional names do not fit — Acme_FileAttachment ships as
#      acme/module-file-attachment — so the dependency graph failed with "not on disk or in
#      composer.lock" while the module sat installed and enabled in vendor/. Found by running the
#      fix for 1 against the project that surfaced it.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

SCRIPT="$PWD/skills/deploy/scripts/preflight.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }

# module <dir> <Module_Name> [<sequence target>…]
module() {
    local dir="$1" name="$2" dep
    shift 2
    mkdir -p "$dir/etc"
    printf "<?php declare(strict_types=1); use Magento\\\\Framework\\\\Component\\\\ComponentRegistrar; ComponentRegistrar::register(ComponentRegistrar::MODULE,'%s',__DIR__);\n" "$name" \
        > "$dir/registration.php"
    {
        echo '<?xml version="1.0"?>'
        echo '<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">'
        echo "  <module name=\"$name\">"
        if [ "$#" -gt 0 ]; then
            echo '    <sequence>'
            for dep in "$@"; do echo "      <module name=\"$dep\"/>"; done
            echo '    </sequence>'
        fi
        echo '  </module>'
        echo '</config>'
    } > "$dir/etc/module.xml"
}

# There is deliberately NO src/app/code in this fixture.
module "$WORK/src/vendor/acme/module-probe" Acme_Probe Magento_Catalog Acme_ProbeBase
cat > "$WORK/src/vendor/acme/module-probe/composer.json" <<'JSON'
{"name": "acme/module-probe", "description": "Probe", "type": "magento2-module", "license": "MIT",
 "require": {}, "autoload": {"files": ["registration.php"]}}
JSON
# A conventionally named dependency: the package-name guess "acme/probebase" never matches it.
module "$WORK/src/vendor/acme/module-probe-base" Acme_ProbeBase
module "$WORK/src/dev-packages/module-probe-dev" Acme_ProbeDev Acme_Probe
# The decoy only SEQUENCES Acme_Ghost. A lookup that grepped for `<module name="Acme_Ghost"` anywhere
# in a module.xml would take this package for Acme_Ghost.
module "$WORK/src/vendor/acme/module-decoy" Acme_Decoy Acme_Ghost
module "$WORK/src/dev-packages/module-needs-ghost" Acme_NeedsGhost Acme_Ghost

cat > "$WORK/src/composer.lock" <<'JSON'
{"packages": [
  {"name": "acme/module-probe", "type": "magento2-module", "version": "1.0.0", "extra": {}},
  {"name": "acme/module-probe-base", "type": "magento2-module", "version": "1.0.0", "extra": {}},
  {"name": "acme/module-decoy", "type": "magento2-module", "version": "1.0.0", "extra": {}}
], "packages-dev": []}
JSON

mkdir -p "$WORK/src/app/etc"
cat > "$WORK/src/app/etc/config.php" <<'PHP'
<?php
return [
    'modules' => [
        'Magento_Catalog' => 1,
        'Acme_Probe' => 1,
        'Acme_ProbeBase' => 1,
        'Acme_ProbeDev' => 1,
        'Acme_Decoy' => 1,
        'Acme_NeedsGhost' => 1,
    ],
];
PHP

# check <json> <name> → "<result>\t<note>"
check() {
    python3 - "$1" "$2" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
for c in doc['preflight']['checks']:
    if c['name'] == sys.argv[2]:
        print('%s\t%s' % (c['result'], c['note']))
        break
else:
    print('missing\t')
PY
}

run_preflight() {
    local out="$1"; shift
    (cd "$WORK" && env "$@" ENV=local STRICT=0 RUNNER="" RUNNER_KIND="null" MAGENTO_CLI="" \
        bash "$SCRIPT") > "$out" 2>/dev/null
}

# --- 1. a Composer-installed module and a dev-packages working copy both resolve ---------------
run_preflight "$WORK/found.json" MODULES="Acme_Probe Acme_ProbeDev"

IFS=$'\t' read -r res note < <(check "$WORK/found.json" "module-registration:Acme_Probe")
[ "$res" = "pass" ] || fail "module-registration:Acme_Probe is '$res' ($note), expected pass"
case "$note" in *vendor/acme/module-probe*) ;; *) fail "Acme_Probe note does not say where it resolved: $note" ;; esac

IFS=$'\t' read -r res note < <(check "$WORK/found.json" "module-registration:Acme_ProbeDev")
[ "$res" = "pass" ] || fail "module-registration:Acme_ProbeDev is '$res' ($note), expected pass"
case "$note" in *dev-packages/module-probe-dev*) ;; *) fail "Acme_ProbeDev note does not say where it resolved: $note" ;; esac

# Acme_Probe sequences Acme_ProbeBase, installed in vendor/ under a conventional package name.
IFS=$'\t' read -r res note < <(check "$WORK/found.json" "dependency-graph")
[ "$res" = "pass" ] || fail "dependency-graph is '$res' ($note), expected pass"

grep -q 'app/code/Acme/Probe' "$WORK/found.json" \
    && fail "a check still looked for the module under app/code: $(cat "$WORK/found.json")"

# --- 2. a module that exists nowhere still fails, and the decoy is not mistaken for it ----------
run_preflight "$WORK/ghost.json" MODULES="Acme_Ghost"
IFS=$'\t' read -r res note < <(check "$WORK/ghost.json" "module-registration:Acme_Ghost")
[ "$res" = "fail" ] || fail "module-registration:Acme_Ghost is '$res' ($note), expected fail"
case "$note" in *module-decoy*) fail "Acme_Ghost resolved to a package that only sequences it: $note" ;; esac

# --- 3. …and a <sequence> target that only the decoy names is still a missing target ------------
run_preflight "$WORK/needs-ghost.json" MODULES="Acme_NeedsGhost"
IFS=$'\t' read -r res note < <(check "$WORK/needs-ghost.json" "dependency-graph")
[ "$res" = "fail" ] || fail "dependency-graph for a sequence on Acme_Ghost is '$res' ($note), expected fail"
case "$note" in *Acme_Ghost*) ;; *) fail "dependency-graph failure does not name Acme_Ghost: $note" ;; esac

if [ "$FAIL" = "0" ]; then
    echo "PASS: preflight resolves supplied modules and their <sequence> targets from app/code,"
    echo "      vendor/ and dev-packages/, by declared module name"
    exit 0
fi
for f in found ghost needs-ghost; do echo "--- $f.json ---"; cat "$WORK/$f.json"; echo; done
exit 1
