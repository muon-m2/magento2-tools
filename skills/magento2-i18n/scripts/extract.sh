#!/usr/bin/env bash
# extract.sh — extract translatable phrases from a module.
#
# Strategy:
#   1. Try Magento CLI: bin/magento i18n:collect-phrases
#   2. Fall back to regex scan via python.
#
# Usage:
#   extract.sh <module-path> [output-csv]
#
# Output: CSV with one row per unique source phrase: `"Phrase",""`.

set -uo pipefail

MODULE_PATH="${1:?usage: extract.sh <module-path> [output-csv]}"
OUTPUT="${2:-/dev/stdout}"

[ -d "$MODULE_PATH" ] || { echo "extract: not a directory: $MODULE_PATH" >&2; exit 2; }

CONTEXT_FILE=".claude/.cache/magento2-context.json"

# Try Magento CLI first.
#
# Runner topology matters here (I18N-5): when the Magento CLI runs inside a container
# (runner_kind=docker-*), `-o <path>` writes the CSV INSIDE the container. If that path
# is not on the host mount (e.g. the container's /tmp), the host-side merge then reads a
# nonexistent file. To stay mount-visible by default we direct the CLI output to a path
# under the Magento root's var/ dir (which is bind-mounted in every standard Magento
# docker layout) and copy it back to $OUTPUT on the host afterwards. For bare PHP the
# var/ path is already on the host, so the copy is a no-op-ish local move.
if [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('$CONTEXT_FILE')).get('magento_cli') or '')")"
    RUNNER_KIND="$(python3 -c "import json; print(json.load(open('$CONTEXT_FILE')).get('runner_kind') or 'null')")"
    MAGENTO_ROOT="$(python3 -c "import json; print(json.load(open('$CONTEXT_FILE')).get('magento_root') or '.')")"
    if [ -n "$MAGENTO_CLI" ]; then
        # argv discipline: word-split the CLI prefix into an array instead of re-splitting
        # via eval (which mangles paths containing spaces/globs). Mirrors deploy preflight.
        # shellcheck disable=SC2206  # intentional word-splitting of the runner+cli prefix
        cli_argv=($MAGENTO_CLI)
        # Mount-visible scratch path. var/ exists and is writable in standard Magento
        # layouts and is bind-mounted into the container, so it is visible on the host.
        cli_out_rel="var/.i18n-extract.$$.csv"
        host_out="${MAGENTO_ROOT%/}/${cli_out_rel}"
        if "${cli_argv[@]}" i18n:collect-phrases "$MODULE_PATH" -o "$cli_out_rel" 2>/dev/null; then
            # The CLI wrote to $cli_out_rel relative to the Magento root. That same file is
            # visible on the host at $host_out (bind mount for docker; identical path for
            # bare). Move it to the caller's requested $OUTPUT.
            if [ -f "$host_out" ]; then
                if [ "$OUTPUT" = "/dev/stdout" ]; then
                    cat "$host_out"
                    rm -f "$host_out"
                else
                    mv -f "$host_out" "$OUTPUT"
                fi
                echo "extract: used magento i18n:collect-phrases (runner_kind=$RUNNER_KIND)" >&2
                exit 0
            fi
            # CLI succeeded but the output isn't visible on the host mount: fall through to
            # the regex scan rather than letting the merge read a nonexistent file.
            echo "extract: collect-phrases output not visible on host ($host_out); using regex fallback" >&2
        fi
    fi
fi

# Regex fallback
if ! command -v python3 >/dev/null 2>&1; then
    echo "extract: python3 required for fallback" >&2
    exit 3
fi

python3 - "$MODULE_PATH" "$OUTPUT" <<'PY'
import csv
import os
import re
import sys

base = sys.argv[1]
out_path = sys.argv[2]

# Quote-aware extraction (I18N-1).
#
# A single regex with a [^'"\\] character class breaks for both string forms: it stops at
# the FIRST quote of either kind, so `__("Don't worry")` and `__('She said "hi"')` never
# match, and escaped quotes are left literally escaped in the captured key (so the CSV key
# won't equal the runtime phrase). Instead we match the two quote styles as separate
# alternations: inside a single-quoted string we allow any char except an unescaped `'`
# (the opposite quote `"` is fine), and vice-versa. The captured group is then UNESCAPED
# so the key equals the runtime phrase string (Magento un-escapes `\'` / `\"` / `\\`).
SQ = r"'((?:\\.|[^'\\])*)'"   # '...': allows escaped chars and bare double-quotes
DQ = r'"((?:\\.|[^"\\])*)"'   # "...": allows escaped chars and bare single-quotes

PHP_PATTERNS = [
    re.compile(r"__\(\s*" + SQ + r"\s*[,)]"),
    re.compile(r"__\(\s*" + DQ + r"\s*[,)]"),
]

XML_PATTERNS = [
    re.compile(r'<(?:label|title)[^>]*translate=["\']true["\'][^>]*>([^<]+)</'),
    re.compile(r'<(?:argument|item)[^>]+translate=["\']true["\'][^>]*>([^<]+)</'),
]

JS_PATTERNS = [
    re.compile(r"(?:\$\.mage\.__|\$t)\(\s*" + SQ + r"\s*\)"),
    re.compile(r"(?:\$\.mage\.__|\$t)\(\s*" + DQ + r"\s*\)"),
]

# Knockout / HTML templates (I18N-2): both the `i18n:` binding and the `translate='...'`
# attribute form, each in single- or double-quoted variants.
HTML_PATTERNS = [
    re.compile(r"""data-bind\s*=\s*["'][^"']*i18n:\s*'((?:\\.|[^'\\])*)'"""),
    re.compile(r'''data-bind\s*=\s*["'][^"']*i18n:\s*"((?:\\.|[^"\\])*)"'''),
    re.compile(r"""\btranslate\s*=\s*"'((?:\\.|[^'\\])*)'"""),
    re.compile(r'''\btranslate\s*=\s*'"((?:\\.|[^"\\])*)"'''),
]


def unescape(s: str) -> str:
    """Turn an extracted source-literal into the runtime phrase string.

    Magento un-escapes the PHP/JS string escapes `\\'`, `\\"`, `\\\\` when the literal is
    evaluated, so the CSV key must store the un-escaped form to match the runtime phrase.
    """
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            nxt = s[i + 1]
            if nxt in ("'", '"', '\\'):
                out.append(nxt)
                i += 2
                continue
        out.append(c)
        i += 1
    return ''.join(out)


def canonicalize(s: str) -> str:
    """Collapse embedded newlines to single spaces.

    Magento joins multi-line `__()` strings into one line; the CSV must be single-line
    (embedded-newline rows are rejected by the loader). Mirror that here so a key like
    `__('Long\\n text')` produces one CSV row.
    """
    return re.sub(r'\s*\r?\n\s*', ' ', s)


phrases = set()


def collect(patterns, content):
    for p in patterns:
        for m in p.finditer(content):
            phrases.add(canonicalize(unescape(m.group(1))))


for root, _, files in os.walk(base):
    # Skip test code. Match a `Test` path SEGMENT (so files directly under a `Test/` dir
    # are excluded too), not the `/Test/` substring which missed top-level Test dirs.
    parts = root.replace('\\', '/').split('/')
    if 'Test' in parts:
        continue
    for name in files:
        path = os.path.join(root, name)
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                content = fh.read()
        except Exception:
            continue
        if name.endswith(('.php', '.phtml')):
            collect(PHP_PATTERNS, content)
        if name.endswith('.xml') or name.endswith('.phtml'):
            collect(XML_PATTERNS, content)
        # JS patterns apply to .js, .html (KO templates) AND .phtml (inline JS), per the
        # extraction-patterns doc which lists inline JS as in-scope for .phtml.
        if name.endswith(('.js', '.html', '.phtml')):
            collect(JS_PATTERNS, content)
        if name.endswith(('.html', '.phtml')):
            collect(HTML_PATTERNS, content)

# Filter: at least one letter
phrases = sorted(p for p in phrases if re.search(r'[A-Za-z]', p))

if out_path == '/dev/stdout':
    out = sys.stdout
else:
    out = open(out_path, 'w', encoding='utf-8', newline='')
writer = csv.writer(out, quoting=csv.QUOTE_ALL)
for p in phrases:
    writer.writerow([p, ''])
if out_path != '/dev/stdout':
    out.close()

print(f"extract: emitted {len(phrases)} unique phrases", file=sys.stderr)
PY
