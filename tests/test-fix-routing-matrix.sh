#!/usr/bin/env bash
# test-fix-routing-matrix.sh — the routing matrix may not drift from the findings schema.
#
# For every (producer, category) pair declared in findings-schema.md's "Per-Skill Category
# Vocabulary", fix-routing.md must name an owner, and every owner it names must be a skill
# that exists on disk (or one of the sanctioned pseudo-owners).
#
# The expectations are DERIVED from findings-schema.md, so adding a category there without a
# routing row fails the suite instead of silently becoming unroutable at runtime.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

python3 <<'PY'
import os
import re
import subprocess
import sys

SCHEMA = "skills/context/references/findings-schema.md"
MATRIX = "skills/context/references/fix-routing.md"

# Owners that are deliberately not a skill directory:
#   inline   — remediate edits these itself (marketplace metadata/packaging)
#   none     — informational only, no remediation owner (breeze-compat/magento-init)
#   unrouted — the explicit "no row matched" bucket
PSEUDO = {"inline", "none", "unrouted"}

schema = open(SCHEMA, encoding="utf-8").read()
vocab = re.search(r"## Per-Skill Category Vocabulary(.*?)\n## ", schema, re.S)
if not vocab:
    sys.exit("FAIL: could not find the Per-Skill Category Vocabulary section in " + SCHEMA)

# Each "### <producer>" heading is followed by `category` tokens separated by "|".
# Harvest only the FIRST backticked token of each pipe-separated term: the parenthetical
# prose after a category may itself contain backticks (the lint section cites
# `subcategory` and `lint/references/surface-invariants.md`), and those are not categories.
TERM = re.compile(r"^`([a-z][a-z0-9_-]*)`")
pairs = []
for block in re.split(r"\n### ", vocab.group(1))[1:]:
    lines = block.splitlines()
    producer = lines[0].strip()
    body = "\n".join(lines[1:])
    for term in body.split("|"):
        m = TERM.match(term.strip())
        if m:
            pairs.append((producer, m.group(1)))

if not pairs:
    sys.exit("FAIL: parsed zero (producer, category) pairs from " + SCHEMA)

skills = {d for d in os.listdir("skills") if os.path.isdir(os.path.join("skills", d))}
problems = []

for producer, category in sorted(set(pairs)):
    out = subprocess.run(
        ["bash", "skills/context/scripts/route-finding.sh",
         f"--skill={producer}", f"--category={category}"],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        problems.append(f"{producer}/{category}: resolver exited {out.returncode}")
        continue
    owner = out.stdout.split("\t")[0].strip()
    if owner == "unrouted":
        problems.append(
            f"{producer}/{category}: declared in findings-schema.md but has no row in fix-routing.md"
        )
    elif owner not in skills and owner not in PSEUDO:
        problems.append(f"{producer}/{category}: owner '{owner}' is not a skill on disk")

# Every owner named anywhere in the matrix must also be real, and every gate must be known.
matrix = open(MATRIX, encoding="utf-8").read()
block = re.search(r"<!-- BEGIN ROUTING TABLE.*?-->(.*?)<!-- END ROUTING TABLE -->", matrix, re.S)
if not block:
    sys.exit("FAIL: ROUTING TABLE markers not found in " + MATRIX)

rows = 0
for line in block.group(1).splitlines():
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 6:
        continue
    rows += 1
    owner, gate = parts[4], parts[5]
    if owner not in skills and owner not in PSEUDO:
        problems.append(f"matrix row names unknown owner '{owner}'")
    if gate not in {"auto", "batch", "manual"}:
        problems.append(f"matrix row for {parts[0]}/{parts[1]} has unknown gate '{gate}'")

if rows == 0:
    sys.exit("FAIL: the ROUTING TABLE block contains no 6-column rows — is it tab-separated?")

if problems:
    print("FAIL: routing matrix drifted from the findings schema")
    for p in sorted(set(problems)):
        print("  " + p)
    sys.exit(1)

print(f"PASS: all {len(set(pairs))} schema categories route to a real owner ({rows} matrix rows)")
PY
