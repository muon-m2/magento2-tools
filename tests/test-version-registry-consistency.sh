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
self_ver_bash_re   = re.compile(r'SKILL_VERSION(?:=\$\{SKILL_VERSION:-|=)([0-9]+\.[0-9]+\.[0-9]+)')
# Header-comment form: "SKILL_VERSION  default: X.Y.Z" (drifts independently of the
# real bash default and misleads readers).
self_ver_doc_re    = re.compile(r'SKILL_VERSION\s+default:\s*([0-9]+\.[0-9]+\.[0-9]+)')
# Python literal fallback inside emitter scripts: os.environ.get('SKILL_VERSION', 'X.Y.Z').
self_ver_py_re     = re.compile(r"os\.environ\.get\(\s*['\"]SKILL_VERSION['\"]\s*,\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]")
# JSON literal emitted by a resolver/emitter script: "skillVersion": "X.Y.Z".
# Scoped to the owning skill's scripts/ dir so example JSON in docs (which may show
# other skills' versions for illustration) is not flagged. This is the TEST-3 fix.
self_ver_json_re   = re.compile(r'"skillVersion"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"')

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
                for lineno, line in enumerate(fh, start=1):
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
                    if own and own in current:
                        for m in self_ver_bash_re.finditer(line):
                            v = m.group(1)
                            if v != current[own]:
                                problems.append(
                                    f"{path}:{lineno} SKILL_VERSION default '{v}' "
                                    f"!= registry '{own}@{current[own]}'"
                                )
                        for m in self_ver_doc_re.finditer(line):
                            v = m.group(1)
                            if v != current[own]:
                                problems.append(
                                    f"{path}:{lineno} SKILL_VERSION header-comment '{v}' "
                                    f"!= registry '{own}@{current[own]}'"
                                )
                        for m in self_ver_py_re.finditer(line):
                            v = m.group(1)
                            if v != current[own]:
                                problems.append(
                                    f"{path}:{lineno} Python SKILL_VERSION fallback '{v}' "
                                    f"!= registry '{own}@{current[own]}'"
                                )
                        if f"{os.sep}scripts{os.sep}" in path:
                            for m in self_ver_json_re.finditer(line):
                                v = m.group(1)
                                if v != current[own]:
                                    problems.append(
                                        f"{path}:{lineno} \"skillVersion\" literal '{v}' "
                                        f"!= registry '{own}@{current[own]}'"
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
