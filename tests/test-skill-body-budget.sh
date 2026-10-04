#!/usr/bin/env bash
# Pins the SKILL.md body budget: on context compaction Claude Code re-attaches only the
# first ~5,000 tokens (~20k chars) of an invoked skill, so a body over 18,000 chars loses
# its tail. Body = text after the closing frontmatter `---`. FAIL > 18,000; WARN > 16,000.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
HARD=18000
SOFT=16000

for f in skills/*/SKILL.md; do
  size=$(python3 -c 'import sys;print(len(open(sys.argv[1]).read().split("---",2)[2]))' "$f")
  if [ "$size" -gt "$HARD" ]; then
    echo "FAIL: $f body is $size chars (> $HARD)"
    FAIL=1
  elif [ "$size" -gt "$SOFT" ]; then
    echo "WARN: $f body is $size chars (> $SOFT)"
  fi
done

[ "$FAIL" -eq 0 ] && echo "PASS: all SKILL.md bodies <= $HARD chars"
exit "$FAIL"
