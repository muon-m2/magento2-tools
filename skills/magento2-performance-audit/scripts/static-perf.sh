#!/usr/bin/env bash
# static-perf.sh — static pattern scan over a module's PHP source.
#
# Emits a JSON array of finding objects per the shared findings schema.

set -uo pipefail

MODULE_PATH="${1:?usage: static-perf.sh <module-path>}"
[ -d "$MODULE_PATH" ] || { echo "[]"; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 2
fi

python3 - "$MODULE_PATH" <<'PY'
import json
import os
import re
import sys

base = sys.argv[1].rstrip('/')

# Every static hit is a *regex candidate*, not a confirmed defect. The hardcoded
# severity below is only a starting hint for sorting; per the skill's mandate the LLM
# pass MUST re-calibrate severity to the actual call context (storefront vs admin,
# hot path vs one-shot, data scale) using references/severity-perf.md. This note rides
# on every finding's description so it is never lost downstream.
CALIBRATION_NOTE = (
    'Regex candidate — confidence is "candidate", not confirmed. The reviewer MUST '
    'calibrate severity to context (storefront vs admin, hot path vs one-shot, data '
    'scale) per references/severity-perf.md rather than trusting this default.'
)

# Receivers that denote an HTTP client, so `->get(`/`->post(` is a real outbound call
# and not a config/registry getter (e.g. $config->get('x'), $registry->get('y')).
HTTP_RECV = r'(?:client|httpClient|http|curl|guzzle|request|adapter|zendClient|restClient)'
# An HTTP-ish call: curl_exec/curl_setopt, or an HTTP verb on an HTTP-client receiver,
# or ->request(. Deliberately excludes a bare `->get(` to avoid config-getter noise.
HTTP_CALL = (
    r'(?:'
    r'curl_(?:exec|setopt|init)\s*\('
    r'|->' + HTTP_RECV + r'\s*->(?:get|post|put|delete|patch|request|send)\s*\('
    r'|\$' + HTTP_RECV + r'\s*->(?:get|post|put|delete|patch|request|send)\s*\('
    r'|->(?:post|put|patch|request)\s*\('
    r')'
)


def find_matching_brace(text, open_idx):
    """Return index just past the brace matching the `{` at text[open_idx], or None.
    A simple depth counter — good enough for locating a loop/constructor body without a
    full PHP parser. Strings/comments may fool it in pathological cases; that is why
    these hits are emitted as `candidate`."""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


def iter_blocks(content, header_re):
    """Yield (match, body_text, body_start) for each construct whose header matches
    header_re and is immediately followed by a `{ ... }` block. Uses brace-depth
    matching so nested if/foreach inside the body do NOT truncate it (fixes the old
    `[^}]{0,500}` window that stopped at the first inner `}`)."""
    for m in header_re.finditer(content):
        brace = content.find('{', m.end() - 1)
        if brace == -1:
            continue
        end = find_matching_brace(content, brace)
        if end is None:
            continue
        yield m, content[brace:end], brace


# Constructs scanned with real brace matching: (header regex, inner call regex).
FOREACH_HEADER = re.compile(r'foreach\s*\([^)]*\)\s*\{')
CONSTRUCT_HEADER = re.compile(r'function\s+__construct\s*\([^)]*\)\s*\{')

REPO_CALL = re.compile(r'Repository\s*->\s*(?:get|getById)\s*\(')
FACTORY_LOAD = re.compile(r'Factory\s*->\s*create\s*\([^)]*\)\s*->\s*load\s*\(')
CONSTRUCT_DB = re.compile(r'->getConnection\s*\(\s*\)')
HTTP_CALL_RE = re.compile(HTTP_CALL)

# Simple single-regex patterns (no body scoping needed).
SIMPLE_PATTERNS = [
    ('full_collection', 'cache', 'medium',
     re.compile(r'getCollection\s*\(\s*\)\s*->getItems\s*\(\s*\)'),
     'getCollection()->getItems() without filter',
     'Apply addFieldToFilter() and setPageSize() before iterating.'),
    ('around_plugin', 'plugin-hotpath', 'medium',
     re.compile(r'function\s+around[A-Z]\w*\s*\(([^)]*)\)'),
     'around plugin defined',
     'Around plugins are expensive; prefer before/after when possible.'),
]

# Block-class detection (PERF-2). A block is flagged for a missing identity ONLY when it
# extends a cacheable, context-sensitive base AND the file defines no getIdentities().
# Recognise BOTH styles:
#   1. FQCN extends:  class Foo extends \Magento\Framework\View\Element\Template
#   2. use-import:    use ...\AbstractBlock;  class Foo extends AbstractBlock
CACHEABLE_BASES_FQCN = re.compile(
    r'class\s+\w+\s+extends\s+\\?Magento\\Framework\\View\\Element\\'
    r'(?:Template|AbstractBlock)\b'
)
# Short-name extends; we confirm the short name was imported from a cacheable base.
SHORTNAME_EXTENDS = re.compile(r'class\s+\w+\s+extends\s+(\w+)\b')
CACHEABLE_SHORT = {'Template', 'AbstractBlock'}
USE_CACHEABLE = re.compile(
    r'use\s+\\?Magento\\Framework\\View\\Element\\(Template|AbstractBlock)\b'
)
HAS_GET_IDENTITIES = re.compile(r'function\s+getIdentities\s*\(')

# Suppression: require an explicit reason. A bare `@perf-audit-ignore` no longer
# silences a finding — the author must justify it: `@perf-audit-ignore reason="..."`.
IGNORE_WITH_REASON = re.compile(r'@perf-audit-ignore\s+reason\s*=\s*["\']?\S')
IGNORE_BARE = re.compile(r'@perf-audit-ignore')


def line_of(content, idx):
    return content[:idx].count('\n') + 1


def suppressed(content, idx, errors):
    """True only if a properly-justified ignore marker sits near idx. A bare marker is
    rejected and noted on stderr so 'suppressed without reason' is observable."""
    surrounding = content[max(0, idx - 200):idx + 200]
    if IGNORE_WITH_REASON.search(surrounding):
        return True
    if IGNORE_BARE.search(surrounding):
        errors.append('@perf-audit-ignore without reason= ignored at offset '
                      f'{idx}; suppression requires reason="..."')
    return False


out = []
fid = 1
errors = []


def emit(rel, content, idx, pid, category, severity, title, recommendation):
    global fid
    if suppressed(content, idx, errors):
        return
    line = line_of(content, idx)
    lines = content.splitlines()
    snippet = lines[line - 1].strip()[:200] if line - 1 < len(lines) else ''
    out.append({
        'id': f'perf-audit-static-{fid:03d}',
        'severity': severity,
        'confidence': 'candidate',
        'category': category,
        'subcategory': pid,
        'title': title,
        'description': CALIBRATION_NOTE,
        'evidence': [{'file': rel, 'line': line, 'snippet': snippet}],
        'recommendation': recommendation,
        'verification': 'Re-run static-perf.sh; pattern should not re-match.'
    })
    fid += 1


for root, _, files in os.walk(base):
    if '/Test/' in root or '/vendor/' in root:
        continue
    for name in files:
        if not name.endswith('.php'):
            continue
        path = os.path.join(root, name)
        try:
            with open(path, encoding='utf-8') as fh:
                content = fh.read()
        except Exception:
            continue
        rel = os.path.relpath(path, base)

        # N+1: repository / factory-load inside a brace-matched foreach body.
        for hm, body, body_start in iter_blocks(content, FOREACH_HEADER):
            rm = REPO_CALL.search(body)
            if rm:
                emit(rel, content, body_start + rm.start(), 'n_plus_one_repo',
                     'n_plus_one', 'high',
                     'Repository call inside foreach (1+N)',
                     'Pre-fetch via getList(addFilter(... in ids)) before the loop.')
            fm = FACTORY_LOAD.search(body)
            if fm:
                emit(rel, content, body_start + fm.start(), 'n_plus_one_load',
                     'n_plus_one', 'high',
                     'Factory->create->load inside foreach (1+N)',
                     'Pre-fetch via a collection or batch repository call.')

        # Constructor work: DB / HTTP inside a brace-matched __construct body.
        for cm, body, body_start in iter_blocks(content, CONSTRUCT_HEADER):
            dm = CONSTRUCT_DB.search(body)
            if dm:
                emit(rel, content, body_start + dm.start(), 'constructor_db',
                     'constructor-work', 'medium',
                     'DB call in __construct',
                     'Defer DB access to method body; constructors should be cheap.')
            hm = HTTP_CALL_RE.search(body)
            if hm:
                emit(rel, content, body_start + hm.start(), 'constructor_http',
                     'constructor-work', 'medium',
                     'HTTP call in __construct',
                     'Defer HTTP calls to method body.')

        # Simple single-regex patterns.
        for pid, category, severity, regex, title, recommendation in SIMPLE_PATTERNS:
            for m in regex.finditer(content):
                emit(rel, content, m.start(), pid, category, severity,
                     title, recommendation)

        # Block-class checks (PERF-2). Decide once per file whether this is a cacheable
        # block and whether it already defines getIdentities().
        is_cacheable_block = False
        if CACHEABLE_BASES_FQCN.search(content):
            is_cacheable_block = True
        else:
            em = SHORTNAME_EXTENDS.search(content)
            if em and em.group(1) in CACHEABLE_SHORT and USE_CACHEABLE.search(content):
                is_cacheable_block = True

        if is_cacheable_block:
            # Anchor the finding at the class declaration line.
            cls = re.search(r'class\s+\w+\s+extends\b', content)
            anchor = cls.start() if cls else 0
            if not HAS_GET_IDENTITIES.search(content):
                emit(rel, content, anchor, 'block_no_identity',
                     'cache-identity', 'medium',
                     'Cacheable block without getIdentities()',
                     'Add getIdentities() returning the cache tags this block depends '
                     'on, so FPC invalidates correctly.')
            # Outbound HTTP inside a storefront block body of any kind.
            hm = HTTP_CALL_RE.search(content)
            if hm:
                emit(rel, content, hm.start(), 'storefront_curl',
                     'storefront-http', 'high',
                     'HTTP call inside a Block class',
                     'Move HTTP to a service; cache the result. Storefront blocks must '
                     'not block on external HTTP.')

if errors:
    for e in errors:
        print(f'static-perf: {e}', file=sys.stderr)

print(json.dumps(out, indent=2))
PY
