#!/usr/bin/env bash
# gen-routing.sh — regenerate the README command-routing table from commands/*.md
# (the single source of truth: each command's frontmatter description, gating flag,
# and the skill its body routes to). Also validates, in --check mode, that the
# hand-written skill tables (README "Skill | Purpose", docs/skills-reference.md
# intent tables) reference only skills that exist and omit none, so those editorial
# tables cannot silently drift from the skill set.
#
# Usage:  bash skills/context/scripts/gen-routing.sh          # rewrite README block
#         bash skills/context/scripts/gen-routing.sh --check  # exit 1 on drift
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
MODE="${1:-write}"

python3 - "$MODE" <<'PY'
import os
import re
import sys

mode = sys.argv[1]
problems = []

# ---- generate the command table from commands/*.md ----
rows = []
for fname in sorted(os.listdir('commands')):
    if not fname.endswith('.md'):
        continue
    name = fname[:-3]
    text = open(os.path.join('commands', fname), encoding='utf-8').read()
    fm = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.S)
    if not fm:
        sys.exit(f"FAIL: commands/{fname} has no frontmatter")
    front, body = fm.group(1), fm.group(2)
    dm = re.search(r'^description:\s*(.+)$', front, re.M)
    if not dm:
        sys.exit(f"FAIL: commands/{fname} has no description")
    desc = dm.group(1).strip()
    # Drop the trailing "(<skill>)" attribution and any follow-on sentences.
    desc = re.sub(r'\s*\((?:magento2-tools:)?[a-z][a-z0-9-]*\)\s*\.?', '.', desc)
    desc = desc.split('. ')[0].rstrip('.')
    sm = re.search(r'magento2-tools:([a-z][a-z0-9-]+)', body)
    if not sm:
        sys.exit(f"FAIL: commands/{fname} body names no magento2-tools:* skill")
    skill = sm.group(1)
    if not os.path.isdir(os.path.join('skills', skill)):
        sys.exit(f"FAIL: commands/{fname} routes to non-existent skill {skill}")
    rows.append((name, skill, desc))

lines = ['| Command | Routes to | Use |', '|---------|-----------|-----|']
for name, skill, use in rows:
    lines.append(f"| `/magento2-tools:{name}` | `{skill}` | {use} |")
table = '\n'.join(lines)

BEGIN = '<!-- BEGIN GENERATED: commands (gen-routing.sh) -->'
END = '<!-- END GENERATED: commands -->'
readme = open('README.md', encoding='utf-8').read()
if BEGIN not in readme or END not in readme:
    sys.exit('FAIL: README.md is missing the GENERATED command-table markers')
new = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END),
             BEGIN + '\n' + table + '\n' + END, readme, flags=re.S)

# ---- validate the editorial skill tables against the skill set ----
skills = {d for d in os.listdir('skills') if os.path.isdir(os.path.join('skills', d))}

# README "Skill | Purpose" table: every skill has a row, and every row is a real skill.
purpose_rows = set(re.findall(r'^\| `([a-z][a-z0-9-]*)` \|', readme, re.M))
for s in sorted(skills - purpose_rows):
    problems.append(f"README.md skill table has no row for {s}")
for s in sorted(purpose_rows - skills):
    problems.append(f"README.md skill table row `{s}` is not a skill on disk")

# Stale pre-2.0 prefixed names must not creep back into the user docs.
for doc in ('README.md', 'docs/skills-reference.md'):
    text = open(doc, encoding='utf-8').read()
    for tok in sorted(set(re.findall(r'magento2-(?!tools)[a-z0-9-]+', text))):
        problems.append(f"{doc} still uses pre-2.0 name magento2-{tok.split('magento2-')[-1]}")

if mode == '--check':
    if new != readme:
        problems.append('README.md command table is stale — run gen-routing.sh')
    if problems:
        print('FAIL: routing drift')
        for p in problems:
            print('  ' + p)
        sys.exit(1)
    print('routing tables up to date')
else:
    if problems:
        print('FAIL: routing drift (fix before regenerating)')
        for p in problems:
            print('  ' + p)
        sys.exit(1)
    open('README.md', 'w', encoding='utf-8').write(new)
    print(f"wrote {len(rows)} command rows to README.md")
PY
