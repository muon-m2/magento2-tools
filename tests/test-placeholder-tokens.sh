#!/usr/bin/env bash
# test-placeholder-tokens.sh — the unknown-token lint (CTX-10 / T4).
#
# Every `{token}` used in any skills/*/templates/ file must be listed in the Registry block
# of skills/magento2-context/references/placeholder-schema.md. A template token that is not
# registered fails this test, so new ad-hoc placeholder spellings cannot drift back in.
#
# Token grammar: `{` + an identifier of [A-Za-z][A-Za-z0-9_.-]* + `}` (single word, no
# spaces) — the same form the registry was generated from. Tokens with spaces (JS/JSON/CSS
# object literals, GraphQL selection sets) are not matched and are not placeholders.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

SCHEMA="skills/magento2-context/references/placeholder-schema.md"
if [ ! -f "$SCHEMA" ]; then
    echo "FAIL: placeholder schema not found at $SCHEMA"
    exit 1
fi

python3 - "$SCHEMA" <<'PY'
import os
import re
import sys

schema_path = sys.argv[1]

# --- parse the ```registry ... ``` fenced block into an allow-set ---
registry = set()
in_block = False
with open(schema_path, encoding="utf-8") as fh:
    for line in fh:
        s = line.strip()
        if s.startswith("```registry"):
            in_block = True
            continue
        if in_block and s.startswith("```"):
            in_block = False
            continue
        if in_block and s:
            registry.add(s)

if not registry:
    print("FAIL: could not parse the ```registry block from the placeholder schema")
    sys.exit(1)

token_re = re.compile(r'\{([A-Za-z][A-Za-z0-9_.-]*)\}')

problems = {}
scanned = 0
for skill in sorted(os.listdir("skills")):
    tdir = os.path.join("skills", skill, "templates")
    if not os.path.isdir(tdir):
        continue
    for root, _dirs, files in os.walk(tdir):
        for fname in files:
            path = os.path.join(root, fname)
            scanned += 1
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
            except OSError:
                continue
            for m in token_re.finditer(text):
                tok = m.group(1)
                if tok not in registry:
                    problems.setdefault(tok, set()).add(path)

if problems:
    print("FAIL: unregistered placeholder token(s) found in templates.")
    print("Add them to the Registry block in", schema_path, "or fix the spelling.")
    for tok in sorted(problems):
        files = ", ".join(sorted(problems[tok])[:4])
        print(f"  {{{tok}}}  in  {files}")
    sys.exit(1)

print(f"all template placeholder tokens registered ({scanned} template files scanned)")
sys.exit(0)
PY
