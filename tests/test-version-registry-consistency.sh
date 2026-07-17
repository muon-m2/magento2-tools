#!/usr/bin/env bash
# Every `<skill>@<version>` token that appears in scripts, templates, or references
# under skills/ MUST match the current version in
# skills/magento2-context/references/skill-versioning.md.
#
# This is the durable fix for the drift documented in v3. After a version bump the
# maintainer runs the harness; this test fails until every emitter and template is
# updated.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

REGISTRY="skills/magento2-context/references/skill-versioning.md"
if [ ! -f "$REGISTRY" ]; then
    echo "FAIL: registry not found at $REGISTRY"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

python3 <<'PY'
import os
import re
import sys

REGISTRY = "skills/magento2-context/references/skill-versioning.md"

# Parse the registry table: lines like "| magento2-context | 1.1.0 | ..."
current = {}
with open(REGISTRY) as fh:
    for line in fh:
        m = re.match(r'^\|\s*(magento2-[a-z0-9-]+)\s*\|\s*([0-9]+\.[0-9]+\.[0-9]+)\s*\|', line)
        if m:
            current[m.group(1)] = m.group(2)

if not current:
    print("FAIL: could not parse any version rows from registry")
    sys.exit(1)

# Walk every file under skills (except _tests) and find skill@version tokens.
# The registry file itself is also scanned: literal X.Y.Z values must match the
# registry row; placeholder forms like {Skill}@{Version} are skipped.
skill_at_re = re.compile(r'(magento2-[a-z0-9-]+)@([0-9]+\.[0-9]+\.[0-9]+)')

# Each file may also declare a *self-version* via a bash default:
#   SKILL_VERSION="${SKILL_VERSION:-X.Y.Z}"  or  SKILL_VERSION=X.Y.Z
# When a file lives under skills/<skill>/, the version it declares should match
# the registry row for <skill>.
#
# JSON literal checks are intentionally omitted: example JSON inside documentation files
# legitimately shows other skills' versions for illustration. Real JSON emission happens
# in scripts and is covered by the bash-default check.
# Accepts the quoted idiom the emitters actually use, plus the unquoted and bare forms:
#   SKILL_VERSION="${SKILL_VERSION:-X}"   SKILL_VERSION=${SKILL_VERSION:-X}
#   SKILL_VERSION=X                       SKILL_VERSION="X"
# The optional ["\x27] after `=` is what the original regex omitted (issue #41); \x27 is a
# single quote, spelled in hex so the raw string needs no quote escaping.
self_ver_bash_re   = re.compile(r'SKILL_VERSION=["\x27]?(?:\$\{SKILL_VERSION:-)?([0-9]+\.[0-9]+\.[0-9]+)')
# Header-comment form: "SKILL_VERSION  default: X.Y.Z" (drifts independently of the
# real bash default and misleads readers).
self_ver_doc_re    = re.compile(r'SKILL_VERSION\s+default:\s*([0-9]+\.[0-9]+\.[0-9]+)')
# Python literal fallback inside emitter scripts: os.environ.get('SKILL_VERSION', 'X.Y.Z').
self_ver_py_re     = re.compile(r"os\.environ\.get\(\s*['\"]SKILL_VERSION['\"]\s*,\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]")
# JSON literal emitted by a resolver/emitter script: "skillVersion": "X.Y.Z".
# Scoped to the owning skill's scripts/ dir so example JSON in docs (which may show
# other skills' versions for illustration) is not flagged. This is the TEST-3 fix.
self_ver_json_re   = re.compile(r'"skillVersion"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"')

# --- Self-check: the guard must honour the forms its own comments claim (issue #41) ---
# self_ver_bash_re once required the UNQUOTED `SKILL_VERSION=${...`, but every emitter
# script uses the QUOTED idiom `SKILL_VERSION="${SKILL_VERSION:-X}"`. The `"` defeated the
# regex, so the guard validated only the doc COMMENT (self_ver_doc_re) and was blind to the
# real default it documents — it could go green while the shipped version drifted. A guard
# that silently fails to check the thing it exists to check is worse than no guard, so it
# now verifies its own instrument before trusting it. If this block fails, the bash regex
# has been re-narrowed; fix the regex, do not weaken this check.
_bash_must_match = {
    'SKILL_VERSION="${SKILL_VERSION:-1.3.2}"': "1.3.2",   # quoted — the real, once-blind form
    'SKILL_VERSION=${SKILL_VERSION:-1.3.2}':   "1.3.2",   # unquoted default
    'SKILL_VERSION=1.3.2':                     "1.3.2",   # bare
    'SKILL_VERSION="1.3.2"':                   "1.3.2",   # bare quoted
}
_bash_must_not_match = [
    "export SKILL_VERSION",                                        # no assignment
    'SKILL_VERSIONS_JSON="[\\"x@${SKILL_VERSION}\\"]"',            # different var; interpolation
    "#   SKILL_VERSION       default: 1.3.2",                      # doc comment (self_ver_doc_re owns it)
]
_selfcheck = []
for _line, _want in _bash_must_match.items():
    _m = self_ver_bash_re.search(_line)
    if not _m or _m.group(1) != _want:
        _selfcheck.append(
            f"self_ver_bash_re failed to extract {_want!r} from a documented form: {_line!r} "
            f"(got {(_m.group(1) if _m else None)!r}) — the guard is blind to this SKILL_VERSION form"
        )
for _line in _bash_must_not_match:
    if self_ver_bash_re.search(_line):
        _selfcheck.append(
            f"self_ver_bash_re false-matched a non-default line: {_line!r} — it would flag noise"
        )
if _selfcheck:
    print("FAIL: version-guard self-check — the guard's own regex is broken:")
    for _p in _selfcheck:
        print("  " + _p)
    sys.exit(1)

def owning_skill(path):
    # path like skills/<skill>/...
    parts = path.split(os.sep)
    try:
        i = parts.index("skills")
    except ValueError:
        return None
    if i + 1 >= len(parts):
        return None
    skill = parts[i + 1]
    return skill if skill.startswith("magento2-") else None

problems = []

for root, dirs, files in os.walk("skills"):
    # Skip the test harness itself — tests legitimately reference fixture versions.
    if "_tests" in dirs:
        dirs.remove("_tests")
    for fname in files:
        path = os.path.join(root, fname)
        # The registry IS scanned now — but only for concrete X.Y.Z literals, and
        # only when they appear inside the version table (rows 1-N near the top).
        # We rely on placeholder-form examples ({Skill}@{Version}) elsewhere in the
        # file so the scan does not produce false positives.
        # Skip binary files and the cache
        if path.endswith((".png", ".jpg", ".gif", ".ico", ".lock")):
            continue
        own = owning_skill(path)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                content = fh.read()
        except OSError:
            continue
        # A shared script may declare a back-compat default identity for a DIFFERENT skill
        # than the directory it lives in — the shared emit-json.sh lives under
        # magento2-context but defaults SKILL_NAME to magento2-module-review for back-compat.
        # Attribute its self-version markers to that declared default when present, so the
        # check still catches drift against the RIGHT skill's registry row.
        self_own = own
        mdecl = re.search(r'SKILL_NAME="\$\{SKILL_NAME:-(magento2-[a-z0-9-]+)\}"', content)
        if mdecl and mdecl.group(1) in current:
            self_own = mdecl.group(1)
        try:
                for lineno, line in enumerate(content.splitlines(), start=1):
                    for m in skill_at_re.finditer(line):
                        skill, version = m.group(1), m.group(2)
                        if skill not in current:
                            problems.append(
                                f"{path}:{lineno} references unknown skill '{skill}@{version}'"
                            )
                        elif current[skill] != version:
                            problems.append(
                                f"{path}:{lineno} '{skill}@{version}' "
                                f"!= registry '{skill}@{current[skill]}'"
                            )
                    if self_own and self_own in current:
                        for m in self_ver_bash_re.finditer(line):
                            v = m.group(1)
                            if v != current[self_own]:
                                problems.append(
                                    f"{path}:{lineno} SKILL_VERSION default '{v}' "
                                    f"!= registry '{self_own}@{current[self_own]}'"
                                )
                        for m in self_ver_doc_re.finditer(line):
                            v = m.group(1)
                            if v != current[self_own]:
                                problems.append(
                                    f"{path}:{lineno} SKILL_VERSION header-comment '{v}' "
                                    f"!= registry '{self_own}@{current[self_own]}'"
                                )
                        for m in self_ver_py_re.finditer(line):
                            v = m.group(1)
                            if v != current[self_own]:
                                problems.append(
                                    f"{path}:{lineno} Python SKILL_VERSION fallback '{v}' "
                                    f"!= registry '{self_own}@{current[self_own]}'"
                                )
                        if f"{os.sep}scripts{os.sep}" in path:
                            for m in self_ver_json_re.finditer(line):
                                v = m.group(1)
                                if v != current[self_own]:
                                    problems.append(
                                        f"{path}:{lineno} \"skillVersion\" literal '{v}' "
                                        f"!= registry '{self_own}@{current[self_own]}'"
                                    )
        except OSError:
            continue

if problems:
    print("FAIL: version registry drift")
    for p in problems[:50]:
        print(f"  {p}")
    if len(problems) > 50:
        print(f"  ... and {len(problems) - 50} more")
    sys.exit(1)

sys.exit(0)
PY
