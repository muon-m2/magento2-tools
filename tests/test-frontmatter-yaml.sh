#!/usr/bin/env bash
# Pins the frontmatter YAML contract: Claude Code parses SKILL.md / command frontmatter as
# YAML, and a skill whose frontmatter does not parse (e.g. a plain multi-line `description:`
# containing `: `) silently disappears from the model's skill listing. Every
# skills/*/SKILL.md, commands/*.md and agents/*.md must have a `---`-delimited frontmatter that
# yaml.safe_load()s to a dict with a non-empty string `description`; skills' `name` must
# equal the directory name (agents: a non-empty `name`, no length cap). Skill descriptions are
# the model's only routing text and sit in the listing every turn: FAIL when one exceeds 600 chars (whitespace-normalised), WARN above 500.
# Needs python3 + PyYAML (SKIP when absent; FAIL under $CI).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
  if [ -n "${CI:-}" ]; then
    echo "FAIL: python3 + PyYAML are required in CI (pip install pyyaml)"
    exit 1
  fi
  echo "SKIP: python3 or PyYAML not found"
  exit 77
fi

python3 - <<'PY'
import glob
import os
import re
import sys

import yaml

fail = 0
checked = 0
DESC_FAIL = 600
DESC_WARN = 500

def check(path, is_skill, is_agent=False):
    global fail, checked
    checked += 1
    text = open(path, encoding='utf-8').read()
    m = re.match(r'^---\n(.*?)\n---(?:\n|$)', text, re.S)
    if not m:
        print(f"FAIL: {path} has no ---delimited frontmatter")
        fail = 1
        return
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        print(f"FAIL: {path} frontmatter is not valid YAML: {' '.join(str(e).split())}")
        fail = 1
        return
    if not isinstance(data, dict):
        print(f"FAIL: {path} frontmatter did not parse to a mapping")
        fail = 1
        return
    desc = data.get('description')
    if not isinstance(desc, str) or not desc.strip():
        print(f"FAIL: {path} description must be a non-empty string (got {type(desc).__name__})")
        fail = 1
    elif is_skill:
        n = len(' '.join(desc.split()))
        if n > DESC_FAIL:
            print(f"FAIL: {path} description is {n} chars (max {DESC_FAIL}; trim to <= {DESC_WARN})")
            fail = 1
        elif n > DESC_WARN:
            print(f"WARN: {path} description is {n} chars (target <= {DESC_WARN})")
    if is_agent and not (isinstance(data.get('name'), str) and data['name'].strip()):
        print(f"FAIL: {path} agent frontmatter needs a non-empty `name`")
        fail = 1
    if is_skill:
        dirname = os.path.basename(os.path.dirname(path))
        if data.get('name') != dirname:
            print(f"FAIL: {path} name {data.get('name')!r} != directory {dirname!r}")
            fail = 1

for p in sorted(glob.glob('skills/*/SKILL.md')):
    check(p, True)
for p in sorted(glob.glob('commands/*.md')):
    check(p, False)
for p in sorted(glob.glob('agents/*.md')):
    check(p, False, True)

if checked == 0:
    print("FAIL: no SKILL.md or command files found to check")
    sys.exit(1)
if not fail:
    print(f"PASS: {checked} frontmatters parse as YAML with a string description")
sys.exit(fail)
PY
