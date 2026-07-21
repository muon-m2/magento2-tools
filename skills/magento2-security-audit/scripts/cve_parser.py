"""The CVE-data YAML reader — the ONE parser for magento-cve-data.yaml and cve-extract.yaml.

This is a deliberately small reader for a fixed six-key schema, NOT a YAML implementation.
PyYAML is not in the stdlib and cannot be assumed on a store's machine, so a real YAML
parser is not available; vendoring one is out of proportion to a fixed schema, and a
"PyYAML if importable, else this" fallback would give two parsers that can disagree about
the same file — the drift bug this module exists to prevent.

It lived inside cve-scan.sh's `python3 <<'PY'` heredoc until 2026-07-21, which forced
cve_data_lint.py and refresh-cve-data.py to reach in with two DIFFERENT regex + ast
extraction hacks to reuse it. It is a plain importable module now; all three import it.

The canonical record layout, after _dedent_record normalises a block to column 0:

    - cve: CVE-0000-0                 <- entry marker, column 0
      severity: high                  <- keys at 2 spaces
      affected:                       <- a key with no value opens a list
        - magento_version_range: "…"  <- list items at 4 spaces
          edition: open-source        <- object continuation keys at 6 spaces
"""
import re


class CveRecordError(Exception):
    """A line inside a CVE record does not match the canonical layout.

    Raised instead of silently dropping or mangling the line. Callers decide the blast
    radius: the lint and the refresh tool let it surface as a hard per-record failure (a
    human is present), while the scanner catches it, skips that ONE record, and reports the
    reason through scanner_errors so the rest of the scan still runs.
    """

    def __init__(self, line_no, line, reason):
        self.line_no = line_no
        self.line = line
        self.reason = reason
        super().__init__(f"line {line_no}: {reason} — {line!r}")


def _scalar(value, line_no, raw):
    """Normalise a scalar value, rejecting what the old parser silently mangled."""
    v = (value or '').strip()
    if not v:
        return ''
    if v.startswith("'"):
        raise CveRecordError(line_no, raw,
                             "single-quoted scalar (the parser strips double quotes only, "
                             "so the quotes would be kept and never match) — use double quotes")
    if v.startswith('"'):
        if len(v) < 2 or not v.endswith('"'):
            raise CveRecordError(line_no, raw, "unterminated double-quoted scalar")
        return v[1:-1]
    if ' #' in v:
        raise CveRecordError(line_no, raw,
                             "unquoted value contains ' #', which YAML reads as a comment "
                             "— quote the value if the '#' is literal")
    return v


def parse_version(v, default_patch=0):
    """Parse '2.4.6-p3' into a tuple (2, 4, 6, 3).

    A missing `-pN` suffix takes `default_patch`. For a range UPPER bound that omits the
    patch (e.g. '2.4.7'), pass default_patch=inf so the bound covers every patch build of
    that release (2.4.7, 2.4.7-p1, …); otherwise '2.4.7' would parse to (2,4,7,0) and
    exclude every -pN — a false negative on the most-patched installs.
    """
    if not v:
        return None
    m = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-p(\d+))?', v.strip())
    if not m:
        return None
    patch = int(m.group(4)) if m.group(4) is not None else default_patch
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)), patch)


def version_in_range(v, range_str):
    """Check if v is in 'A - B' (inclusive) range string."""
    if not range_str or '-' not in range_str:
        return False
    parts = [p.strip() for p in range_str.split(' - ', 1)]
    if len(parts) != 2:
        return False
    # Lower bound: missing patch ⇒ 0 (>= the base release). Upper bound: missing patch ⇒ inf
    # (<= every patch build of that release).
    lo = parse_version(parts[0])
    hi = parse_version(parts[1], default_patch=float('inf'))
    cur = parse_version(v)
    if not (lo and hi and cur):
        return False
    return lo <= cur <= hi


def load_cve_data_yaml(path):
    """Read magento-cve-data.yaml. Return (status, entries_raw_text_list).

    status is the value of the top-level `status:` key. entries are the YAML records
    under the `entries:` list, each as a raw text block beginning with `- cve:`.
    """
    import os
    if not path or not os.path.exists(path):
        return ('missing', [])
    text = open(path, encoding='utf-8').read()
    status = 'unknown'
    in_entries = False
    records = []
    current = []
    for line in text.splitlines():
        # Detect top-level status
        m = re.match(r'^status:\s*(\S+)', line)
        if m:
            status = m.group(1).strip()
            continue
        # Detect entries: list start
        if re.match(r'^entries:', line):
            in_entries = True
            continue
        # A block sequence ends where its parent mapping's next key begins. Without this,
        # in_entries latched forever and a top-level block AFTER entries: (cve-extract.yaml
        # ends with `exclude:`) had its `- cve:` line collected as a phantom advisory.
        if in_entries and re.match(r'^[^\s#-]', line):
            in_entries = False
            if current:
                records.append('\n'.join(current))
                current = []
            continue
        if not in_entries:
            continue
        # Inside entries — collect blocks separated by `- cve:` at any indent.
        if re.match(r'^\s*- cve:', line):
            if current:
                records.append('\n'.join(current))
            current = [line]
        elif current:
            current.append(line)
    if current:
        records.append('\n'.join(current))
    # Dedent each record to column 0 so parse_record (which expects `- cve:` at indent 0,
    # keys at 2, list items at 4) works regardless of how deeply the YAML nests the entries
    # list. The old parser only accepted column-0 entries, so the natural 2-space nesting
    # under `entries:` produced all-empty records and ZERO matches with no error (SEC-2).
    records = [_dedent_record(r) for r in records if '- cve:' in r]
    return (status, records)


def _dedent_record(rec):
    """Strip the indentation of the record's `- cve:` line from every line in the block."""
    lines = rec.split('\n')
    base = 0
    for ln in lines:
        m = re.match(r'^(\s*)- cve:', ln)
        if m:
            base = len(m.group(1))
            break
    if base == 0:
        return rec
    out = []
    for ln in lines:
        out.append(ln[base:] if ln[:base].strip() == '' else ln.lstrip())
    return '\n'.join(out)


_RE_CVE = re.compile(r'^- cve:(?:[ ](.*))?$')
_RE_KEY = re.compile(r'^  (\w+):(?:[ ](.*))?$')
_RE_ITEM = re.compile(r'^    - (.*)$')
_RE_OBJKEY = re.compile(r'^      (\w+):(?:[ ](.*))?$')
# Inside a list item: a key only when the colon is followed by a space or ends the line.
# Without that rule "- https://a/b" split into {'https': '//a/b'} — a string became a dict.
_RE_INLINE_KEY = re.compile(r'^(\w+):(?:[ ](.*))?$')


def parse_record(rec):
    """Parse ONE dedented CVE record into a dict.

    Small reader for a fixed schema, not a YAML implementation — see the module docstring.
    Anything outside the canonical layout raises CveRecordError rather than being dropped:
    a silently missing `severity` reports a critical advisory as medium, and nothing in the
    lint would catch it.
    """
    out = {'affected': [], 'fixed_in': []}
    cur_list = None
    cur_obj = None
    for line_no, raw in enumerate(rec.splitlines(), 1):
        line = raw.rstrip()
        if not line.strip():
            continue
        if line.lstrip().startswith('#'):
            continue
        lead = line[:len(line) - len(line.lstrip())]
        if '\t' in lead:
            raise CveRecordError(line_no, line,
                                 "tab in the indentation — YAML indentation must be spaces")

        m = _RE_CVE.match(line)
        if m:
            out['cve'] = _scalar(m.group(1), line_no, line)
            cur_list = None
            cur_obj = None
            continue

        m = _RE_KEY.match(line)
        if m:
            key = m.group(1)
            if m.group(2) is None:
                # No value at all after the colon — this is how a key OPENS a list
                # (`affected:`, `fixed_in:`, `fixed_by_patch:`, `detect:`). Must stay a
                # list-opener: load-bearing for those four keys across every record.
                cur_list = []
                out[key] = cur_list
                cur_obj = None
            else:
                val = _scalar(m.group(2), line_no, line)
                if val == '':
                    # An EXPLICITLY empty value (`severity: ""`), not a bare `key:`. Without
                    # this check it fell into the list-opener branch above and silently
                    # became `[]` — e.g. `severity: ""` turned into `severity: []`, and
                    # cve-scan.sh's severity_norm([]) falls through to 'medium'. That is the
                    # second silent route to the exact bug this module exists to eliminate.
                    raise CveRecordError(line_no, line,
                                         f"'{key}' has an explicitly empty value — if you "
                                         "meant to open a list, remove everything after the "
                                         f"colon (`{key}:`); an empty quoted/blank value "
                                         "after a colon is never valid here")
                out[key] = val
                cur_list = None
                cur_obj = None
            continue

        m = _RE_ITEM.match(line)
        if m:
            if cur_list is None:
                raise CveRecordError(line_no, line,
                                     "list item with no list open above it — a key must "
                                     "introduce the list (e.g. `  fixed_in:`)")
            body = m.group(1).strip()
            km = _RE_INLINE_KEY.match(body)
            if km:
                cur_obj = {km.group(1): _scalar(km.group(2), line_no, line)}
                cur_list.append(cur_obj)
            else:
                cur_list.append(_scalar(body, line_no, line))
                cur_obj = None
            continue

        m = _RE_OBJKEY.match(line)
        if m:
            if cur_obj is None:
                raise CveRecordError(line_no, line,
                                     "object continuation key with no list-item object "
                                     "above it")
            cur_obj[m.group(1)] = _scalar(m.group(2), line_no, line)
            continue

        raise CveRecordError(line_no, line,
                             "unexpected indentation or shape — expected `- cve:` at "
                             "column 0, keys at 2 spaces, list items at 4, object keys at 6")
    return out
