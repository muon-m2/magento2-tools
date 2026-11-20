#!/usr/bin/env bash
# test-security-false-positives.sh — two false-positive classes in the security scanners.
#   1. secret-scan: hits in test code (Test/, tests/, dev/tests/, Test/Mftf/, *Test.php,
#      *.test.mjs, *.spec.js, fixtures/) drop to low/candidate — kept, never dropped —
#      across all three backends (gitleaks, trufflehog, regex). The same hit in
#      production code keeps its severity.
#   2. advisory-scan: at module/vendor scope, composer-audit advisories for packages
#      outside the target's dependency closure (computed from composer.lock) become
#      info/site-scope; packages inside the closure keep their severity. Site scope and
#      a missing target composer.json leave severities untouched.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

SECRET="$PWD/skills/security/scripts/secret-scan.sh"
ADV="$PWD/skills/security/scripts/advisory-scan.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# check <label> <json-file> <python-assertions using f = findings list>
check() {
    local label="$1" file="$2" code="$3"
    if python3 - "$file" "$code" <<'PY'
import json, sys
f = json.load(open(sys.argv[1]))
by = {e['evidence'][0]['file'].split('/mod/', 1)[-1]: e for e in f} if f and 'evidence' in f[0] else {}
exec(sys.argv[2])
PY
    then ok "$label"; else bad "$label"; fi
}

# ---------------------------------------------------------------------------------
# 1. secret-scan
# ---------------------------------------------------------------------------------
MOD="$WORK/mod"
mkdir -p "$MOD/Test/Unit/Model" "$MOD/Test/Mftf/ActionGroup" "$MOD/Model" "$MOD/view/web/js" \
         "$MOD/tests/fixtures" "$MOD/dev/tests/api"
KEY='AKIAQWERTYUIOPASDFGH'
for f in Test/Unit/Model/ClientTest.php Test/Mftf/ActionGroup/Click.xml Model/Foo.php \
         view/web/js/widget.test.mjs view/web/js/widget.spec.js tests/fixtures/data.json \
         dev/tests/api/Call.php; do
    printf '<?php\n$k = "%s";\n' "$KEY" > "$MOD/$f"
done
TEST_FILES='["Test/Unit/Model/ClientTest.php","Test/Mftf/ActionGroup/Click.xml","view/web/js/widget.test.mjs","view/web/js/widget.spec.js","tests/fixtures/data.json","dev/tests/api/Call.php"]'
ASSERT_SECRET="
tests = $TEST_FILES
assert len(f) == 7, len(f)
for t in tests:
    e = by[t]
    assert e['severity'] == 'low', (t, e['severity'])
    assert e['confidence'] == 'candidate', t
    assert 'test code' in e['description'], e.get('description')
    assert 'not rotated' in e['description'] or 'not rotate' in e['description'], e['description']
prod = by['Model/Foo.php']
assert prod['severity'] == 'critical', prod['severity']
assert prod.get('confidence') != 'candidate'
"

# 1a. gitleaks backend (stub writes its report to --report-path, exits 1 = leaks found)
mkdir -p "$WORK/gl"
cat > "$WORK/gl/gitleaks" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in --report-path=*) rp="${a#*=}";; --source=*) src="${a#*=}";; esac; done
python3 - "$rp" "$src" <<'PY'
import json, os, sys
rp, src = sys.argv[1], sys.argv[2]
out = []
for root, _, files in os.walk(src):
    for n in files:
        out.append({"Description": "Generic API Key", "File": os.path.join(root, n), "StartLine": 2})
json.dump(out, open(rp, "w"))
PY
exit 1
STUB
chmod +x "$WORK/gl/gitleaks"
PATH="$WORK/gl:$PATH" bash "$SECRET" "$MOD" > "$WORK/gl.json" 2>/dev/null
check "gitleaks: test-code hits low/candidate, Model/ hit stays critical" "$WORK/gl.json" "$ASSERT_SECRET"

# 1b. trufflehog backend — hide gitleaks behind a stub that errors out (exit 2 → fall through)
mkdir -p "$WORK/th"
printf '#!/usr/bin/env bash\nexit 2\n' > "$WORK/th/gitleaks"
cat > "$WORK/th/trufflehog" <<'STUB'
#!/usr/bin/env bash
src="${@: -1}"
python3 - "$src" <<'PY'
import json, os, sys
for root, _, files in os.walk(sys.argv[1]):
    for n in files:
        print(json.dumps({"DetectorName": "AWS", "Verified": True,
            "SourceMetadata": {"Data": {"Filesystem": {"file": os.path.join(root, n), "line": 2}}}}))
PY
STUB
chmod +x "$WORK/th/gitleaks" "$WORK/th/trufflehog"
PATH="$WORK/th:$PATH" bash "$SECRET" "$MOD" > "$WORK/th.json" 2>/dev/null
check "trufflehog: test-code hits low/candidate, Model/ hit stays critical" "$WORK/th.json" "$ASSERT_SECRET"

# 1c. regex fallback — a PATH with neither tool on it
mkdir -p "$WORK/rx"
for t in python3 dirname mktemp head tr rm cat; do
    p="$(command -v "$t")" && ln -sf "$p" "$WORK/rx/$t"
done
PATH="$WORK/rx" "$(command -v bash)" "$SECRET" "$MOD" > "$WORK/rx.json" 2>/dev/null
check "regex: test-code hits low/candidate, Model/ hit stays critical" "$WORK/rx.json" "$ASSERT_SECRET"

# 1d. classification is relative to the scan root: a root that itself sits under tests/
#     must not turn every production hit into test code.
mkdir -p "$WORK/tests/proj/Model"
printf '<?php\n$k = "%s";\n' "$KEY" > "$WORK/tests/proj/Model/Foo.php"
PATH="$WORK/rx" "$(command -v bash)" "$SECRET" "$WORK/tests/proj" > "$WORK/rx2.json" 2>/dev/null
check "regex: scan root under tests/ does not downgrade production hits" "$WORK/rx2.json" \
    "assert len(f) == 1 and f[0]['severity'] == 'critical', f"

# ---------------------------------------------------------------------------------
# 2. advisory-scan dependency closure
# ---------------------------------------------------------------------------------
P="$WORK/proj"
mkdir -p "$P/vendor/muon/module-a" "$P/bin2"
cat > "$P/composer.lock" <<'JSON'
{"packages": [
  {"name": "muon/module-a", "require": {"php": "^8.3", "acme/used": "^1", "magento/framework": "*"}},
  {"name": "acme/used", "require": {"acme/deep": "^2", "ext-json": "*", "lib-libxml": "*"}},
  {"name": "acme/deep", "require": {"Acme/Cycle": "*"}},
  {"name": "acme/cycle", "require": {"acme/deep": "*"}},
  {"name": "magento/framework", "require": {"php": "*", "composer-plugin-api": "^2"}},
  {"name": "x/bundle", "replace": {"acme/replaced": "self.version"}, "require": {"acme/via-replace": "*"}},
  {"name": "acme/via-replace"},
  {"name": "muon/module-passkey", "require": {"web-auth/webauthn-lib": "^5"}},
  {"name": "web-auth/webauthn-lib", "require": {"symfony/serializer": "^7"}},
  {"name": "symfony/serializer"}
],
"packages-dev": [{"name": "dev/only"}]}
JSON
cat > "$P/vendor/muon/module-a/composer.json" <<'JSON'
{"name": "muon/module-a", "require": {"php": "^8.3", "acme/used": "^1", "magento/framework": "*", "acme/replaced": "*"},
 "require-dev": {"dev/only": "*"}}
JSON
cat > "$P/bin2/composer" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"advisories": {
  "acme/deep":          [{"title": "Deep bug", "severity": "high", "cve": "CVE-1", "sources": []}],
  "magento/framework":  [{"title": "Core bug", "severity": "critical", "cve": "CVE-2", "sources": []}],
  "muon/module-a":      [{"title": "Self bug", "severity": "medium", "cve": "CVE-3", "sources": []}],
  "acme/via-replace":   [{"title": "Replace bug", "severity": "high", "cve": "CVE-4", "sources": []}],
  "symfony/serializer": [{"title": "Serializer bug", "severity": "high", "cve": "CVE-5", "sources": []}],
  "dev/only":           [{"title": "Dev bug", "severity": "low", "cve": "CVE-6", "sources": []}]
}}
JSON
exit 1
STUB
chmod +x "$P/bin2/composer"

run_adv() { (cd "$P" && PATH="$P/bin2:$PATH" PATCH_STATUS=0 env "$@" bash "$ADV" composer.lock 2>/dev/null); }
ASSERT_PKG='
sev = {e["tags"][0]: e for e in f}
'

run_adv TARGET_PATH="$P/vendor/muon/module-a" SCOPE=module > "$WORK/a1.json"
check "module scope: in-closure advisories keep severity" "$WORK/a1.json" "$ASSERT_PKG
assert len(f) == 6, len(f)
assert sev['acme/deep']['severity'] == 'high'
assert sev['magento/framework']['severity'] == 'critical'
assert sev['muon/module-a']['severity'] == 'medium'
assert sev['acme/via-replace']['severity'] == 'high', 'replace/provide must resolve to the providing package'
"
check "module scope: out-of-closure advisories become info/site-scope" "$WORK/a1.json" "$ASSERT_PKG
for p in ('symfony/serializer', 'dev/only'):
    e = sev[p]
    assert e['severity'] == 'info', (p, e['severity'])
    assert 'site-scope' in e['title'], e['title']
    assert 'muon/module-a' not in e['title'], 'module name in title would defeat cross-module dedupe'
    assert \"not in muon/module-a's dependency tree\" in e['description'], e['description']
    assert 'site-scope' in e['tags']
"

# SCOPE unset defaults to module (build-findings does not export its default).
run_adv TARGET_PATH="vendor/muon/module-a" > "$WORK/a2.json"
check "unset SCOPE + relative TARGET_PATH: same closure filtering" "$WORK/a2.json" "$ASSERT_PKG
assert sev['symfony/serializer']['severity'] == 'info'
assert sev['acme/deep']['severity'] == 'high'
"

run_adv TARGET_PATH="$P/vendor/muon/module-a" SCOPE=site > "$WORK/a3.json"
check "site scope: severities unchanged" "$WORK/a3.json" "$ASSERT_PKG
assert sev['symfony/serializer']['severity'] == 'high'
assert not any(e['severity'] == 'info' for e in f)
"

run_adv TARGET_PATH="$P" SCOPE=module > "$WORK/a4.json"
check "target is the project root: severities unchanged" "$WORK/a4.json" "$ASSERT_PKG
assert sev['symfony/serializer']['severity'] == 'high'
"

run_adv TARGET_PATH="$P/nowhere" SCOPE=module > "$WORK/a5.json"
check "no target composer.json: severities unchanged" "$WORK/a5.json" "$ASSERT_PKG
assert sev['symfony/serializer']['severity'] == 'high'
"

echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
