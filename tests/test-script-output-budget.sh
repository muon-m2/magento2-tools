#!/usr/bin/env bash
# Pins the quiet-by-default output contract of the plugin's chatty scripts (token-optimization W6b):
# default stdout is a short summary (<= 5 lines) plus every warning/error; per-item lines appear only
# with VERBOSE=1 / --verbose; exit codes and failure visibility are unchanged.
#   - context/scripts/add-license-headers.sh  (already summary-only; skip warning stays on stderr)
#   - module-create/scripts/create-dirs.sh     (per-surface lines + dir tree -> VERBOSE)
#   - module-create/scripts/verify-created.sh  (per-check PASS lines -> VERBOSE; WARN/FAIL always shown)
#   - feature/scripts/smoke-baseline.sh        (echoed key=value details -> VERBOSE)
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

lines() { wc -l < "$1" | tr -d ' '; }

# run <name> <env-assign|-> <cmd...>: stdout -> $WORK/<name>.out, stderr -> .err, rc -> $RC
run() {
    local name="$1"; shift
    local envv="$1"; shift
    if [[ "$envv" == "-" ]]; then
        "$@" >"$WORK/$name.out" 2>"$WORK/$name.err" </dev/null
    else
        env "$envv" "$@" >"$WORK/$name.out" 2>"$WORK/$name.err" </dev/null
    fi
    RC=$?
}

# --- add-license-headers.sh: 20 PHP files + one that must be flagged -----------------------------
LIC="$WORK/lic/Acme/Probe"; mkdir -p "$LIC"
for i in $(seq 1 20); do printf '<?php\nclass A%s {}\n' "$i" > "$LIC/F$i.php"; done
printf 'not php\n' > "$LIC/bad.php"
run lic - bash "$ROOT/skills/context/scripts/add-license-headers.sh" "$LIC" Acme
[[ $RC -eq 0 ]] || fail "add-license-headers exit $RC, expected 0"
[[ "$(lines "$WORK/lic.out")" -le 5 ]] || fail "add-license-headers default stdout $(lines "$WORK/lic.out") lines (> 5)"
grep -q 'stamped: 20' "$WORK/lic.out" || fail "add-license-headers summary line missing stamped count"
grep -q "skipped (no '<?php'" "$WORK/lic.err" || fail "add-license-headers skip warning no longer printed"

# --- create-dirs.sh --------------------------------------------------------------------------------
CD="$WORK/cd/app/code"; mkdir -p "$CD"
export MODULE_DIR="$CD"
run cd MODULE_DIR="$CD" bash "$ROOT/skills/module-create/scripts/create-dirs.sh" Acme Probe persistence admin_ui rest_api cron
[[ $RC -eq 0 ]] || fail "create-dirs exit $RC, expected 0"
[[ "$(lines "$WORK/cd.out")" -le 5 ]] || fail "create-dirs default stdout $(lines "$WORK/cd.out") lines (> 5)"
grep -q 'Run scripts/verify-created.sh' "$WORK/cd.out" || fail "create-dirs default output lost the verify hint"
[[ -d "$CD/Acme/Probe/Ui/DataProvider" ]] || fail "create-dirs did not create the admin_ui directories"
# failure stays visible: existing module without --augment
run cdf MODULE_DIR="$CD" bash "$ROOT/skills/module-create/scripts/create-dirs.sh" Acme Probe core
[[ $RC -eq 1 ]] || fail "create-dirs on an existing module exit $RC, expected 1"
grep -q 'already exists' "$WORK/cdf.err" || fail "create-dirs 'already exists' error not on stderr"
# verbose
run cdv VERBOSE=1 bash "$ROOT/skills/module-create/scripts/create-dirs.sh" Acme Probeb persistence admin_ui
[[ $RC -eq 0 ]] || fail "create-dirs VERBOSE=1 exit $RC, expected 0"
[[ "$(lines "$WORK/cdv.out")" -ge 15 ]] || fail "create-dirs VERBOSE=1 printed only $(lines "$WORK/cdv.out") lines"
grep -q 'Directory structure:' "$WORK/cdv.out" || fail "create-dirs VERBOSE=1 lost the directory tree"
run cdv2 MODULE_DIR="$CD" bash "$ROOT/skills/module-create/scripts/create-dirs.sh" Acme Probec core --verbose
grep -q 'Directory structure:' "$WORK/cdv2.out" || fail "create-dirs --verbose flag not honoured"
grep -q -- '--verbose' "$WORK/cdv2.out" && fail "create-dirs treated --verbose as a surface"
[[ -d "$CD/Acme/Probec/etc" ]] || fail "create-dirs --verbose broke surface parsing"

# --- verify-created.sh: an incomplete module must still report its failures --------------------------
VM="$WORK/cd/app/code/Acme/Probe"   # only dirs, so required files are missing
run vc - bash "$ROOT/skills/module-create/scripts/verify-created.sh" "$VM"
[[ $RC -eq 1 ]] || fail "verify-created on an incomplete module exit $RC, expected 1"
grep -q '✗' "$WORK/vc.out" || fail "verify-created hid its FAIL lines in default mode"
grep -q 'RESULT: FAIL' "$WORK/vc.out" || fail "verify-created default output lost the RESULT verdict"
grep -q 'PASS:' "$WORK/vc.out" || fail "verify-created default output lost the tally"
# a clean-ish module: default stdout is short, verbose has the per-check lines
GOOD="$WORK/good/Acme/Ok"; mkdir -p "$GOOD/etc"
printf '<?php\n/**\n * Copyright © Acme. All rights reserved.\n * See LICENSE.txt for license details.\n */\ndeclare(strict_types=1);\n' > "$GOOD/registration.php"
run vg - bash "$ROOT/skills/module-create/scripts/verify-created.sh" "$GOOD"
run vgv VERBOSE=1 bash "$ROOT/skills/module-create/scripts/verify-created.sh" "$GOOD"
vg_rc_default=$RC
[[ "$(lines "$WORK/vgv.out")" -gt "$(lines "$WORK/vg.out")" ]] || fail "verify-created VERBOSE=1 not longer than default"
grep -q '✓' "$WORK/vgv.out" || fail "verify-created VERBOSE=1 lost the per-check PASS lines"
grep -q '✓' "$WORK/vg.out" && fail "verify-created default mode printed per-check PASS lines"
run vga - bash "$ROOT/skills/module-create/scripts/verify-created.sh" "$GOOD" --verbose
grep -q '✓' "$WORK/vga.out" || fail "verify-created --verbose flag not honoured"
[[ "$vg_rc_default" -eq "$RC" ]] || fail "verify-created exit code differs between default and --verbose"

# --- smoke-baseline.sh -------------------------------------------------------------------------------
MG="$WORK/mg"; mkdir -p "$MG/app/etc" "$MG/var/log"; : > "$MG/app/etc/env.php"; echo x > "$MG/var/log/exception.log"
run sb - bash "$ROOT/skills/feature/scripts/smoke-baseline.sh" "$WORK/base.txt" "$MG"
[[ $RC -eq 0 ]] || fail "smoke-baseline exit $RC, expected 0"
[[ "$(lines "$WORK/sb.out")" -le 5 ]] || fail "smoke-baseline default stdout $(lines "$WORK/sb.out") lines (> 5)"
grep -q "baseline written: $WORK/base.txt" "$WORK/sb.out" || fail "smoke-baseline lost the 'baseline written' line"
grep -q '^magento_root=' "$WORK/base.txt" || fail "smoke-baseline baseline file lost magento_root="
run sbv VERBOSE=1 bash "$ROOT/skills/feature/scripts/smoke-baseline.sh" "$WORK/base2.txt" "$MG"
grep -q 'size_bytes=' "$WORK/sbv.out" || fail "smoke-baseline VERBOSE=1 lost the detail lines"
run sbf - bash "$ROOT/skills/feature/scripts/smoke-baseline.sh" --verbose "$WORK/base3.txt" "$MG"
grep -q 'size_bytes=' "$WORK/sbf.out" && [[ -f "$WORK/base3.txt" ]] || fail "smoke-baseline --verbose flag not honoured / mistaken for the output path"
run sbn - bash "$ROOT/skills/feature/scripts/smoke-baseline.sh"
[[ $RC -eq 64 ]] || fail "smoke-baseline with no args exit $RC, expected 64"
run sbr - bash "$ROOT/skills/feature/scripts/smoke-baseline.sh" "$WORK/none.txt" "$WORK/empty-root-does-not-exist"
[[ $RC -eq 0 || $RC -eq 2 ]] || fail "smoke-baseline unexpected exit $RC"

if [[ $FAIL -eq 0 ]]; then
    echo "PASS: plugin scripts are quiet by default and verbose on request"
    exit 0
fi
exit 1
