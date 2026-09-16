#!/usr/bin/env bash
# route-finding.sh — resolve ONE finding to the skill that owns its remediation.
#
# The matrix lives in context/references/fix-routing.md between the ROUTING TABLE
# markers; this script is a thin, ordered first-match-wins lookup over it. Routing is
# deterministic on purpose: the owning skill must never be picked ad hoc.
#
# Usage:
#   route-finding.sh --skill=<producer> --category=<cat> [--subcategory=<sub>]
#                    [--severity=<sev>] [--file=<path>] [--breeze]
#
# Output: one TSV line — owner<TAB>gate<TAB>rationale
# Exit:   always 0. An unmatched finding prints owner `unrouted`; it is data to report,
#         not an error to raise.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

MATRIX="skills/context/references/fix-routing.md"
if [ ! -f "$MATRIX" ]; then
    echo "route-finding: matrix not found at $MATRIX" >&2
    exit 2
fi

SKILL="" CATEGORY="" SUBCATEGORY="" SEVERITY="" FILE="" BREEZE=0
for arg in "$@"; do
    case "$arg" in
        --skill=*)       SKILL="${arg#*=}" ;;
        --category=*)    CATEGORY="${arg#*=}" ;;
        --subcategory=*) SUBCATEGORY="${arg#*=}" ;;
        --severity=*)    SEVERITY="${arg#*=}" ;;
        --file=*)        FILE="${arg#*=}" ;;
        --breeze)        BREEZE=1 ;;
        *) echo "route-finding: unknown argument '$arg'" >&2; exit 2 ;;
    esac
done
if [ -z "$SKILL" ] || [ -z "$CATEGORY" ]; then
    echo "route-finding: --skill and --category are required" >&2
    exit 2
fi

MATRIX="$MATRIX" SKILL="$SKILL" CATEGORY="$CATEGORY" SUBCATEGORY="$SUBCATEGORY" \
SEVERITY="$SEVERITY" FILE="$FILE" BREEZE="$BREEZE" python3 <<'PY'
import fnmatch
import os
import re
import sys

RANK = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}

text = open(os.environ["MATRIX"], encoding="utf-8").read()
m = re.search(r"<!-- BEGIN ROUTING TABLE.*?-->(.*?)<!-- END ROUTING TABLE -->", text, re.S)
if not m:
    sys.stderr.write("route-finding: ROUTING TABLE markers not found in matrix\n")
    sys.exit(2)

skill = os.environ["SKILL"]
category = os.environ["CATEGORY"]
subcategory = os.environ.get("SUBCATEGORY", "")
severity = os.environ.get("SEVERITY", "")
path = os.environ.get("FILE", "")
breeze = os.environ.get("BREEZE") == "1"


def condition_holds(cond):
    if cond == "-":
        return True
    if cond == "breeze":
        return breeze
    if cond.startswith("!file~"):
        return bool(path) and not fnmatch.fnmatch(path, cond[6:])
    if cond.startswith("file~"):
        return bool(path) and fnmatch.fnmatch(path, cond[5:])
    if cond.startswith("sev>="):
        return RANK.get(severity, -1) >= RANK.get(cond[5:], 99)
    return False


for line in m.group(1).splitlines():
    line = line.rstrip("\n")
    if not line.strip() or line.strip().startswith("```"):
        continue
    parts = line.split("\t")
    if len(parts) != 6:
        continue
    r_skill, r_cat, r_sub, r_cond, owner, gate = parts
    if r_skill != skill or r_cat != category:
        continue
    if r_sub != "*" and r_sub != subcategory:
        continue
    if not condition_holds(r_cond):
        continue
    rationale = f"{r_skill}/{r_cat}"
    if r_sub != "*":
        rationale += f" [{r_sub}]"
    if r_cond != "-":
        rationale += f" when {r_cond}"
    rationale += f" → {owner}"
    print(f"{owner}\t{gate}\t{rationale}")
    sys.exit(0)

print(f"unrouted\tmanual\tno matching row for {skill}/{category}")
PY
