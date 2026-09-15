#!/usr/bin/env bash
# extract-surface.sh — READ-ONLY module surface extractor.
#
# Given a Magento 2 module path, greps and parses the module's own files to produce
# a surface JSON describing which documented surfaces exist and what entries each
# contains. Every entry records its source file path.
#
# This script NEVER mutates any file, NEVER installs any tool, and NEVER modifies
# the working tree. It only reads files.
#
# Usage:
#   MODULE_PATH=/path/to/app/code/Acme/OrderExport bash extract-surface.sh
#   # or
#   bash extract-surface.sh /path/to/app/code/Acme/OrderExport
#
# Output: JSON written to SURFACE_FILE (default: a new temp file whose path is printed
# to stdout for callers that chain further processing; the caller owns and removes it).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Intentionally used for potential future cross-skill references.
: "${SCRIPT_DIR}"

MODULE_PATH="${MODULE_PATH:-${1:-}}"
: "${MODULE_PATH:?MODULE_PATH is required (pass as env var or \$1)}"

if [ ! -d "$MODULE_PATH" ]; then
    echo "extract-surface: module directory does not exist: $MODULE_PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Python helper — all parsing is done in a single python3 heredoc to avoid
# requiring xmllint, jq, or any other tool beyond coreutils + python3.
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
    echo "extract-surface: python3 is required but not found on PATH" >&2
    exit 1
fi

SURFACE_FILE="${SURFACE_FILE:-}"
CREATED_SURFACE_FILE=0
if [ -z "$SURFACE_FILE" ]; then
    # Created OUTSIDE any directory this script cleans up, because the path is the output: the caller
    # reads it after this script has exited, and owns and removes it. It used to sit in a temp dir
    # whose EXIT trap deleted it first, so the printed path never existed for the caller.
    if ! SURFACE_FILE="$(mktemp "${TMPDIR:-/tmp}/surface.XXXXXX")"; then
        echo "extract-surface: could not create a temp output file" >&2
        exit 1
    fi
    CREATED_SURFACE_FILE=1
fi

if ! python3 - "$MODULE_PATH" "$SURFACE_FILE" <<'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

XSI_TYPE = '{http://www.w3.org/2001/XMLSchema-instance}type'

module_path = sys.argv[1]
surface_file = sys.argv[2]

def rel(path):
    """Return path relative to module_path, with forward slashes."""
    try:
        return os.path.relpath(path, module_path).replace(os.sep, '/')
    except ValueError:
        return path

def read_xml(fpath):
    """Parse an XML file; return ElementTree root or None on error."""
    try:
        tree = ET.parse(fpath)
        return tree.getroot()
    except Exception:
        return None

# ---------------------------------------------------------------------------
# 1. Public API surface — @api annotations in PHP files
# ---------------------------------------------------------------------------
def extract_api(base):
    entries = []
    for dirpath, _dirs, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.php'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, encoding='utf-8', errors='replace') as fh:
                    lines = fh.readlines()
            except OSError:
                continue
            for i, line in enumerate(lines, start=1):
                if '@api' not in line:
                    continue
                # Scan forward for the class/interface declaration
                kind = None
                name = None
                for j in range(i, min(i + 10, len(lines))):
                    m = re.search(r'\b(interface|class)\s+(\w+)', lines[j - 1])
                    if m:
                        kind = m.group(1)
                        name = m.group(2)
                        break
                if kind and name:
                    entries.append({
                        'class': name,
                        'kind': kind,
                        'file': rel(fpath),
                        'line': i,
                    })
    return entries

# ---------------------------------------------------------------------------
# 1b. Public @api method signatures
# ---------------------------------------------------------------------------
METHOD_RE = re.compile(
    r'public\s+function\s+(\w+)\s*\(([^)]*)\)\s*:\s*\??([\\\w\[\]\|]+)'
)

def extract_api_methods(base):
    """Public method signatures of @api interfaces/classes."""
    entries = []
    for dirpath, _dirs, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.php'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, encoding='utf-8', errors='replace') as fh:
                    text = fh.read()
            except OSError:
                continue
            if '@api' not in text:
                continue
            cm = re.search(r'\b(?:interface|class)\s+(\w+)', text)
            cls = cm.group(1) if cm else fname[:-4]
            for m in METHOD_RE.finditer(text):
                params = []
                for p in m.group(2).split(','):
                    p = p.strip()
                    pm = re.search(r'([\\\w\[\]\|]+)\s+\$(\w+)', p)
                    if pm:
                        params.append({'name': pm.group(2), 'type': pm.group(1)})
                entries.append({
                    'class': cls,
                    'method': m.group(1),
                    'params': params,
                    'return_type': m.group(3),
                    'file': rel(fpath),
                    'line': text[:m.start()].count('\n') + 1,
                })
    return entries

# ---------------------------------------------------------------------------
# 2. Events observed — etc/events.xml and area variants
# ---------------------------------------------------------------------------
def extract_events_observed(base):
    entries = []
    area_files = [
        'etc/events.xml',
        'etc/frontend/events.xml',
        'etc/adminhtml/events.xml',
        'etc/webapi_rest/events.xml',
        'etc/crontab/events.xml',
    ]
    for af in area_files:
        fpath = os.path.join(base, af)
        if not os.path.isfile(fpath):
            continue
        root = read_xml(fpath)
        if root is None:
            continue
        area = af.split('/')[1] if af.count('/') >= 2 else 'global'
        if area == 'events.xml':
            area = 'global'
        for event_el in root.findall('.//event'):
            event_name = event_el.get('name', '')
            for obs_el in event_el.findall('observer'):
                entries.append({
                    'event_name': event_name,
                    'observer_name': obs_el.get('name', ''),
                    'observer_class': obs_el.get('instance', ''),
                    'area': area,
                    'file': rel(fpath),
                })
    return entries

# ---------------------------------------------------------------------------
# 3. Events fired — dispatch( calls in PHP files
# ---------------------------------------------------------------------------
def extract_events_fired(base):
    entries = []
    dispatch_re = re.compile(
        r'(?:->|\$)(?:_eventManager|eventManager|_dispatchEvent)\s*->\s*dispatch\s*\(\s*[\'"]([^\'"]+)[\'"]'
        r'|->\s*dispatch\s*\(\s*[\'"]([^\'"]+)[\'"]'
    )
    for dirpath, _dirs, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.php'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, encoding='utf-8', errors='replace') as fh:
                    for lineno, line in enumerate(fh, start=1):
                        m = dispatch_re.search(line)
                        if m:
                            event_name = m.group(1) or m.group(2)
                            if event_name:
                                entries.append({
                                    'event_name': event_name,
                                    'file': rel(fpath),
                                    'line': lineno,
                                })
            except OSError:
                continue
    return entries

# ---------------------------------------------------------------------------
# 4 & 5. Plugins and Preferences — etc/di.xml and area variants
# ---------------------------------------------------------------------------
def extract_plugins_preferences(base):
    plugins = []
    preferences = []
    area_files = [
        ('global', 'etc/di.xml'),
        ('frontend', 'etc/frontend/di.xml'),
        ('adminhtml', 'etc/adminhtml/di.xml'),
        ('webapi_rest', 'etc/webapi_rest/di.xml'),
        ('graphql', 'etc/graphql/di.xml'),
    ]
    for area, af in area_files:
        fpath = os.path.join(base, af)
        if not os.path.isfile(fpath):
            continue
        root = read_xml(fpath)
        if root is None:
            continue
        for type_el in root.findall('.//type'):
            type_name = type_el.get('name', '')
            for plugin_el in type_el.findall('plugin'):
                plugins.append({
                    'plugin_name': plugin_el.get('name', ''),
                    'plugin_class': plugin_el.get('type', ''),
                    'target_type': type_name,
                    'sort_order': plugin_el.get('sortOrder', ''),
                    'disabled': plugin_el.get('disabled', 'false'),
                    'area': area,
                    'file': rel(fpath),
                })
        for pref_el in root.findall('.//preference'):
            preferences.append({
                'for': pref_el.get('for', ''),
                'type': pref_el.get('type', ''),
                'area': area,
                'file': rel(fpath),
            })
    return plugins, preferences

# ---------------------------------------------------------------------------
# 6. CLI commands
# ---------------------------------------------------------------------------
def extract_cli_commands(base):
    entries = []
    setname_re = re.compile(r'setName\s*\(\s*[\'"]([^\'"]+)[\'"]')
    setdesc_re = re.compile(r'setDescription\s*\(\s*[\'"]([^\'"]+)[\'"]')
    cmd_dir = os.path.join(base, 'Console', 'Command')
    if not os.path.isdir(cmd_dir):
        return entries
    for dirpath, _dirs, files in os.walk(cmd_dir):
        for fname in files:
            if not fname.endswith('.php'):
                continue
            fpath = os.path.join(dirpath, fname)
            cmd_name = ''
            cmd_desc = ''
            class_name = fname.replace('.php', '')
            try:
                with open(fpath, encoding='utf-8', errors='replace') as fh:
                    text = fh.read()
                m = setname_re.search(text)
                if m:
                    cmd_name = m.group(1)
                m = setdesc_re.search(text)
                if m:
                    cmd_desc = m.group(1)
            except OSError:
                continue
            if cmd_name:
                entries.append({
                    'command_name': cmd_name,
                    'class': class_name,
                    'description': cmd_desc,
                    'file': rel(fpath),
                })
    return entries

# ---------------------------------------------------------------------------
# 7. Admin config paths
# ---------------------------------------------------------------------------
def extract_config_paths(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'adminhtml', 'system.xml')
    if not os.path.isfile(fpath):
        return entries
    root = read_xml(fpath)
    if root is None:
        return entries
    for section_el in root.findall('.//section'):
        section_id = section_el.get('id', '')
        for group_el in section_el.findall('.//group'):
            group_id = group_el.get('id', '')
            for field_el in group_el.findall('.//field'):
                field_id = field_el.get('id', '')
                label_el = field_el.find('label')
                label = label_el.text if label_el is not None else ''
                entries.append({
                    'config_path': f'{section_id}/{group_id}/{field_id}',
                    'label': label or '',
                    'type': field_el.get('type', 'text'),
                    'file': rel(fpath),
                })
    return entries

# ---------------------------------------------------------------------------
# 8. Cron jobs
# ---------------------------------------------------------------------------
def extract_cron_jobs(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'crontab.xml')
    if not os.path.isfile(fpath):
        return entries
    root = read_xml(fpath)
    if root is None:
        return entries
    for group_el in root.findall('.//group'):
        group_id = group_el.get('id', '')
        for job_el in group_el.findall('job'):
            schedule_el = job_el.find('schedule')
            config_path_el = job_el.find('config_path')
            schedule = ''
            if schedule_el is not None and schedule_el.text:
                schedule = schedule_el.text.strip()
            elif config_path_el is not None and config_path_el.text:
                schedule = f'config:{config_path_el.text.strip()}'
            entries.append({
                'job_name': job_el.get('name', ''),
                'instance': job_el.get('instance', ''),
                'method': job_el.get('method', 'execute'),
                'schedule': schedule,
                'group': group_id,
                'file': rel(fpath),
            })
    return entries

# ---------------------------------------------------------------------------
# 9. REST routes + DTO walker helpers
# ---------------------------------------------------------------------------
SCALAR_EXAMPLE = {
    'string': 'string', 'int': 0, 'integer': 0, 'float': 0.0,
    'bool': True, 'boolean': True, 'void': None, 'mixed': None,
    'array': [], 'iterable': [],
}

# JSON Schema counterpart of SCALAR_EXAMPLE. `array`/`mixed` deliberately map to the
# empty schema {} — "anything" — and are reported by scan_bare_types() instead.
SCALAR_SCHEMA = {
    'string': {'type': 'string'}, 'int': {'type': 'integer'},
    'integer': {'type': 'integer'}, 'float': {'type': 'number'},
    'bool': {'type': 'boolean'}, 'boolean': {'type': 'boolean'},
    'array': {}, 'iterable': {}, 'mixed': {},
}

# PHP scalar -> OpenAPI primitive, for path-parameter typing.
PHP_TO_OPENAPI = {
    'int': 'integer', 'integer': 'integer', 'float': 'number', 'double': 'number',
    'bool': 'boolean', 'boolean': 'boolean', 'string': 'string',
}

BARE_TYPE_MESSAGE = (
    'Bare `array`/`mixed` breaks Magento\'s own schema generator '
    '(Magento\\Framework\\Reflection\\TypeProcessor). While present, '
    'GET /rest/<store>/schema returns HTTP 500 for EVERY service on the '
    'installation, not just this module. Use a typed array (`string[]`, `mixed[]`) '
    'or a DTO interface.'
)

def _first_concrete_type(rtype):
    """Reduce a PHP union type to its first concrete (non-null) member, e.g.
    'SampleInterface|null' -> 'SampleInterface', 'string|int' -> 'string'.
    A leading nullable marker is stripped ('?Foo' -> 'Foo'); ask _is_nullable()
    for that bit instead."""
    parts = [p.strip().lstrip('?') for p in rtype.split('|')]
    parts = [p for p in parts if p and p.lower().lstrip('\\') not in ('null', 'void', 'mixed')]
    return parts[0] if parts else rtype.strip().lstrip('?')

def _is_nullable(rtype):
    """True for '?Foo' and for any union carrying an explicit `null` member."""
    rtype = rtype.strip()
    if rtype.startswith('?'):
        return True
    return any(p.strip().lstrip('\\').lower() == 'null' for p in rtype.split('|'))

def _ns_to_path(base, fqcn):
    """Map Vendor\\Module\\Sub\\Class -> {base}/Sub/Class.php (module-local only)."""
    parts = fqcn.lstrip('\\').split('\\')
    if len(parts) < 3:
        return None
    vendor_module = os.path.normpath(base).split(os.sep)[-2:]
    if parts[:2] != vendor_module:
        return None  # type lives outside this module; cannot resolve statically
    fpath = os.path.join(base, *parts[2:]) + '.php'
    return fpath if os.path.isfile(fpath) else None

def _getter_to_field(method):
    name = re.sub(r'^(get|is|has)', '', method)
    return re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower()

def _parse_use_map(text):
    """Map short/aliased class name -> FQCN from `use` statements."""
    use_map = {}
    for m in re.finditer(r'^\s*use\s+([\\\w]+)(?:\s+as\s+(\w+))?\s*;', text, re.M):
        fqcn = m.group(1).lstrip('\\')
        alias = m.group(2) or fqcn.split('\\')[-1]
        use_map[alias] = fqcn
    return use_map

def _current_namespace(text):
    m = re.search(r'^\s*namespace\s+([\\\w]+)\s*;', text, re.M)
    return m.group(1).lstrip('\\') if m else ''

def _resolve_type(name, use_map, current_ns):
    """Expand a possibly-short class name to an FQCN via use-map + namespace."""
    name = name.lstrip('\\')
    if '\\' in name:
        return name
    if name in use_map:
        return use_map[name]
    if current_ns:
        return f'{current_ns}\\{name}'
    return name

GETTER_RE = re.compile(
    r'public\s+function\s+((?:get|is|has)[A-Z]\w*)\s*\([^)]*\)\s*:\s*(\??[\\\w\[\]\|]+)'
)

DOCBLOCK_RE = re.compile(r'/\*\*(.*?)\*/', re.S)
# Only whitespace and method modifiers may sit between a docblock and the member
# it documents; anything else means the docblock belongs to an earlier member.
DOC_GAP_RE = re.compile(r'^(?:\s|public|protected|private|static|final|abstract)*$')

def _docblock_before(text, pos):
    """Inner text of the docblock immediately preceding `pos`, or ''."""
    doc = ''
    for d in DOCBLOCK_RE.finditer(text):
        if d.end() > pos:
            break
        if DOC_GAP_RE.match(text[d.end():pos]):
            doc = d.group(1)
    return doc

def _doc_return_type(doc):
    m = re.search(r'@return\s+([^\s*]+)', doc or '')
    return m.group(1) if m else ''

def _doc_param_type(doc, name):
    m = re.search(r'@param\s+([^\s*]+)\s+\$' + re.escape(name) + r'\b', doc or '')
    return m.group(1) if m else ''

def _normalize_doc_array(t):
    """`array<int, Foo>` / `array<Foo>` -> `Foo[]`; anything else unchanged."""
    m = re.match(r'^array<\s*[^,>]+\s*,\s*([^>]+)>$', t)
    if m:
        return m.group(1).strip() + '[]'
    m = re.match(r'^array<\s*([^,>]+)\s*>$', t)
    if m:
        return m.group(1).strip() + '[]'
    return t

def _effective_type(text, pos, native, param_name=None):
    """Magento types collections as a native `array` hint plus a `@return Foo[]`
    docblock — the canonical SearchResults shape. When the native hint is bare,
    prefer the docblock annotation so the collection element type survives."""
    concrete = _first_concrete_type(native or '')
    if concrete.lstrip('\\').split('\\')[-1].lower() not in ('array', 'iterable', 'mixed'):
        return native
    doc = _docblock_before(text, pos)
    annotated = (_doc_param_type(doc, param_name) if param_name
                 else _doc_return_type(doc))
    annotated = _normalize_doc_array(annotated.strip()) if annotated else ''
    if not annotated:
        return native
    if annotated.lstrip('\\').split('\\')[-1].lower() in ('array', 'iterable', 'mixed'):
        return native
    return annotated

def _type_to_example(base, rtype, depth, seen, use_map=None, cur_ns=''):
    use_map = use_map or {}
    rtype = _first_concrete_type(rtype)
    is_array = rtype.endswith('[]')
    core = (rtype[:-2] if is_array else rtype).lstrip('\\')
    short = core.split('\\')[-1].lower()
    if short in SCALAR_EXAMPLE:
        val = SCALAR_EXAMPLE[short]
    else:
        fqcn = _resolve_type(core, use_map, cur_ns)
        nested = walk_dto_shape(base, fqcn, depth + 1, seen)
        val = nested if nested is not None else 'string'
    return [val] if is_array else val

def walk_dto_shape(base, fqcn, depth=0, seen=None):
    if seen is None:
        seen = set()
    if depth > 4 or fqcn in seen:
        return {}
    seen = seen | {fqcn}
    fpath = _ns_to_path(base, fqcn)
    if not fpath:
        return None  # unresolved -> caller omits the example
    try:
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
    except OSError:
        return None
    use_map = _parse_use_map(text)
    cur_ns = _current_namespace(text)
    shape = {}
    for m in GETTER_RE.finditer(text):
        rtype = _effective_type(text, m.start(), m.group(2))
        shape[_getter_to_field(m.group(1))] = _type_to_example(
            base, rtype, depth, seen, use_map, cur_ns)
    return shape

def _schema_title(fqcn):
    """Component name for a DTO: its short name minus a trailing `Interface`."""
    short = fqcn.lstrip('\\').split('\\')[-1]
    trimmed = short[:-len('Interface')] if short.endswith('Interface') else short
    return trimmed or short

def _type_to_schema(base, rtype, depth, seen, use_map=None, cur_ns=''):
    """JSON Schema counterpart of _type_to_example(): same module-local resolution,
    same depth cap and cycle guard, but emits type nodes instead of placeholder
    values. Returns None only for `void`."""
    use_map = use_map or {}
    nullable = _is_nullable(rtype)
    concrete = _first_concrete_type(rtype)
    is_array = concrete.endswith('[]')
    core = (concrete[:-2] if is_array else concrete).lstrip('\\')
    short = core.split('\\')[-1].lower()
    if short == 'void':
        return None
    if short in SCALAR_SCHEMA:
        node = dict(SCALAR_SCHEMA[short])
    else:
        fqcn = _resolve_type(core, use_map, cur_ns)
        nested = walk_dto_schema(base, fqcn, depth + 1, seen)
        # Same degradation the example walker applies to non-module-local types.
        node = nested if nested is not None else {'type': 'string'}
    if is_array:
        node = {'type': 'array', 'items': node}
    if nullable:
        node = dict(node)
        node['nullable'] = True
    return node

def walk_dto_schema(base, fqcn, depth=0, seen=None):
    """Object schema for a module-local DTO interface: one property per get*/is*/has*
    getter, snake_cased. `title` carries the component name so the emitter can hoist
    the node into components/schemas and $ref it."""
    if seen is None:
        seen = set()
    if depth > 4 or fqcn in seen:
        return {}
    seen = seen | {fqcn}
    fpath = _ns_to_path(base, fqcn)
    if not fpath:
        return None  # unresolved -> caller degrades to {"type": "string"}
    try:
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
    except OSError:
        return None
    use_map = _parse_use_map(text)
    cur_ns = _current_namespace(text)
    props = {}
    for m in GETTER_RE.finditer(text):
        rtype = _effective_type(text, m.start(), m.group(2))
        node = _type_to_schema(base, rtype, depth, seen, use_map, cur_ns)
        props[_getter_to_field(m.group(1))] = {} if node is None else node
    return {'type': 'object', 'title': _schema_title(fqcn), 'properties': props}

# ---------------------------------------------------------------------------
# 9b. Bare `array` / `mixed` preflight over the reachable Api/ graph
# ---------------------------------------------------------------------------
FUNC_SIG_RE = re.compile(
    r'function\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*(\??[\\\w\[\]\|]+))?'
)
PARAM_RE = re.compile(r'(\??[\\\w\[\]\|]+)\s+\$(\w+)')
# `array<int, Foo>`, `array{a: int}`, `mixed[]` and `arrayish` are all typed enough
# for TypeProcessor; only a truly bare `array`/`mixed` is rejected.
DOC_BARE_RE = re.compile(r'@(param|return)\s+(array|mixed)(?![\w<{\[])([^\r\n]*)')

def _is_bare(phptype):
    if phptype is None:
        return False
    concrete = _first_concrete_type(phptype)
    if concrete.endswith('[]'):
        return False
    return concrete.lstrip('\\').split('\\')[-1].lower() in ('array', 'mixed')

def _local_types_in(base, text, use_map, cur_ns):
    """Module-local FQCNs referenced by this file's method signatures."""
    out = set()
    for m in FUNC_SIG_RE.finditer(text):
        candidates = [pm.group(1) for pm in PARAM_RE.finditer(m.group(2) or '')]
        if m.group(3):
            candidates.append(m.group(3))
        for t in candidates:
            concrete = _first_concrete_type(t)
            core = (concrete[:-2] if concrete.endswith('[]') else concrete).lstrip('\\')
            short = core.split('\\')[-1].lower()
            if short in SCALAR_SCHEMA or short in ('void', 'self', 'static', 'this', 'null'):
                continue
            fqcn = _resolve_type(core, use_map, cur_ns)
            if _ns_to_path(base, fqcn):
                out.add(fqcn)
    return out

def scan_bare_types(base, routes):
    """Breadth-first over the module-local interface graph reachable from every
    route's service class, reporting each bare `array`/`mixed` in a docblock
    annotation or a native type hint. Warning, never a hard stop."""
    warnings = []
    seen_types = set()
    seen_files = set()
    queue = [r.get('service_class', '') for r in routes if r.get('service_class')]
    while queue:
        fqcn = queue.pop(0)
        if not fqcn or fqcn in seen_types:
            continue
        seen_types.add(fqcn)
        fpath = _ns_to_path(base, fqcn)
        if not fpath:
            continue
        try:
            with open(fpath, encoding='utf-8', errors='replace') as fh:
                text = fh.read()
        except OSError:
            continue
        use_map = _parse_use_map(text)
        cur_ns = _current_namespace(text)
        for t in sorted(_local_types_in(base, text, use_map, cur_ns)):
            if t not in seen_types:
                queue.append(t)
        rpath = rel(fpath)
        if rpath in seen_files:
            continue
        seen_files.add(rpath)
        hits = []
        for lineno, line in enumerate(text.splitlines(), start=1):
            dm = DOC_BARE_RE.search(line)
            if dm:
                tail = (dm.group(3) or '').rstrip()
                var = re.search(r'\$(\w+)', tail)
                hits.append((lineno,
                             ('@%s %s%s' % (dm.group(1), dm.group(2), tail)).strip(),
                             var.group(1) if var else ''))
        for m in FUNC_SIG_RE.finditer(text):
            lineno = text[:m.start()].count('\n') + 1
            name = m.group(1)
            doc = _docblock_before(text, m.start())
            # A bare native hint is fine when the docblock types it (`array` +
            # `@return Foo[]` is Magento's own SearchResults idiom); it is only
            # unrepresentable when nothing types it at all.
            for pm in PARAM_RE.finditer(m.group(2) or ''):
                if _is_bare(pm.group(1)) and not _doc_param_type(doc, pm.group(2)):
                    hits.append((lineno, '%s(%s $%s)' % (name, pm.group(1), pm.group(2)),
                                 pm.group(2)))
            if _is_bare(m.group(3)) and not _doc_return_type(doc):
                hits.append((lineno, '%s(): %s' % (name, m.group(3)), name))
        for lineno, annotation, symbol in hits:
            warnings.append({
                'kind': 'bare_type',
                'file': rpath,
                'line': lineno,
                'symbol': symbol or '',
                'annotation': annotation,
                'message': BARE_TYPE_MESSAGE,
            })
    deduped = {}
    for w in warnings:
        deduped[(w['file'], w['line'], w['annotation'])] = w
    return [deduped[k] for k in sorted(deduped)]

def enrich_rest_examples(base, routes):
    sig_tmpl = r'public\s+function\s+{m}\s*\(([^)]*)\)\s*:\s*(\??[\\\w\[\]\|]+)'
    for r in routes:
        r['request_shape'] = None
        r['response_shape'] = None
        r['request_schema'] = None
        r['response_schema'] = None
        r['request_param'] = None
        r['throws'] = []
        fpath = _ns_to_path(base, r.get('service_class', ''))
        meth = r.get('service_method', '')
        if not fpath or not meth:
            continue
        try:
            with open(fpath, encoding='utf-8', errors='replace') as fh:
                text = fh.read()
        except OSError:
            continue
        use_map = _parse_use_map(text)
        cur_ns = _current_namespace(text)
        sig = re.search(sig_tmpl.replace('{m}', re.escape(meth)), text)
        if not sig:
            continue
        param_types = {}
        for p in sig.group(1).split(','):
            pm = re.search(r'(\??[\\\w\[\]\|]+)\s+\$(\w+)', p.strip())
            if not pm:
                continue
            ptype, pname = pm.group(1), pm.group(2)
            param_types[pname] = ptype
            concrete = _first_concrete_type(ptype)
            core = (concrete[:-2] if concrete.endswith('[]') else concrete).lstrip('\\')
            # Detect by resolved FQCN, not by method name: `getList` is a convention.
            if _resolve_type(core, use_map, cur_ns).endswith('\\Api\\SearchCriteriaInterface'):
                r['is_search_criteria'] = True
            if r['request_shape'] is None:
                ex = _type_to_example(base, ptype, 0, set(), use_map, cur_ns)
                if isinstance(ex, dict):
                    r['request_shape'] = ex
                    r['request_schema'] = _type_to_schema(
                        base, ptype, 0, set(), use_map, cur_ns)
                    # Magento's ServiceInputProcessor keys the request body by the
                    # service-method parameter name: {"sample": {...}}, never a bare DTO.
                    r['request_param'] = pname
        for pp in r.get('path_params', []):
            ptype = param_types.get(pp['name'])
            if not ptype:
                continue
            concrete = _first_concrete_type(ptype)
            core = (concrete[:-2] if concrete.endswith('[]') else concrete).lstrip('\\')
            pp['type'] = PHP_TO_OPENAPI.get(core.split('\\')[-1].lower(), 'string')
        ret = _effective_type(text, sig.start(), sig.group(2))
        r['response_shape'] = _type_to_example(base, ret, 0, set(), use_map, cur_ns)
        r['response_schema'] = _type_to_schema(base, ret, 0, set(), use_map, cur_ns)
        throws_text = _docblock_before(text, sig.start())
        r['throws'] = sorted({_resolve_type(t, use_map, cur_ns)
                              for t in re.findall(r'@throws\s+\\?([\\\w]+)', throws_text)})
    return routes

def extract_rest_routes(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'webapi.xml')
    if not os.path.isfile(fpath):
        return entries
    root = read_xml(fpath)
    if root is None:
        return entries
    for route_el in root.findall('.//route'):
        service_el = route_el.find('service')
        resources_el = route_el.find('resources')
        auth_scopes = []
        if resources_el is not None:
            for res_el in resources_el.findall('resource'):
                auth_scopes.append(res_el.get('ref', ''))
        url = route_el.get('url', '')
        # `:param` is Magento's path-parameter syntax; OpenAPI/Postman want `{param}`.
        param_names = re.findall(r':(\w+)', url)
        acl_resources = [a for a in auth_scopes if a not in ('anonymous', 'self')]
        if 'anonymous' in auth_scopes:
            auth_kind = 'anonymous'
        elif acl_resources:
            auth_kind = 'acl'
        elif 'self' in auth_scopes:
            auth_kind = 'self'
        else:
            auth_kind = 'acl'
        entries.append({
            'method': route_el.get('method', ''),
            'url': url,
            'url_template': re.sub(r':(\w+)', r'{\1}', url),
            'path_params': [{'name': n, 'type': 'string'} for n in param_names],
            'service_class': service_el.get('class', '') if service_el is not None else '',
            'service_method': service_el.get('method', '') if service_el is not None else '',
            'auth': ', '.join(auth_scopes),
            'auth_kind': auth_kind,
            'acl_resources': acl_resources,
            'is_search_criteria': False,
            'file': rel(fpath),
        })
    return entries

# ---------------------------------------------------------------------------
# 10. GraphQL
# ---------------------------------------------------------------------------
def extract_graphql(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'schema.graphqls')
    if not os.path.isfile(fpath):
        return entries
    type_re = re.compile(
        r'^(type|input|interface|extend\s+type|extend\s+input)\s+(\w+)'
    )
    field_re = re.compile(r'^\s+(\w+)\s*(?:\([^)]*\))?\s*:\s*([\[\]\w!]+)')
    try:
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            lines = fh.readlines()
    except OSError:
        return entries
    current_kind = None
    current_name = None
    current_fields = []
    for line in lines:
        m = type_re.match(line.strip())
        if m:
            if current_name:
                entries.append({
                    'kind': current_kind,
                    'name': current_name,
                    'fields': current_fields,
                    'file': rel(fpath),
                })
            current_kind = m.group(1).replace('  ', ' ')
            current_name = m.group(2)
            current_fields = []
        elif current_name and '{' not in line and '}' not in line:
            fm = field_re.match(line)
            if fm:
                current_fields.append({'name': fm.group(1), 'type': fm.group(2).strip('[]!')})
    if current_name:
        entries.append({
            'kind': current_kind,
            'name': current_name,
            'fields': current_fields,
            'file': rel(fpath),
        })
    return entries

# ---------------------------------------------------------------------------
# 10b. GraphQL operations
# ---------------------------------------------------------------------------
def extract_graphql_operations(base):
    fpath = os.path.join(base, 'etc', 'schema.graphqls')
    if not os.path.isfile(fpath):
        return []
    try:
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            lines = fh.readlines()
    except OSError:
        return []
    ops = []
    head_re = re.compile(r'^(?:extend\s+type|type)\s+(Query|Mutation)\b')
    field_re = re.compile(r'^\s*(\w+)\s*(?:\(([^)]*)\))?\s*:\s*([\[\]\w!]+)')
    resolver_re = re.compile(r'@resolver\s*\(\s*class\s*:\s*"([^"]+)"')
    in_block = False
    kind = None
    for line in lines:
        h = head_re.match(line.strip())
        if h:
            in_block, kind = True, h.group(1)
            continue
        if in_block and line.strip().startswith('}'):
            in_block = False
            continue
        if in_block:
            fm = field_re.match(line)
            if fm:
                args = []
                if fm.group(2):
                    for a in fm.group(2).split(','):
                        am = re.match(r'\s*(\w+)\s*:\s*([\[\]\w!]+)', a)
                        if am:
                            args.append({'name': am.group(1), 'type': am.group(2).strip('[]!')})
                rm = resolver_re.search(line)
                ops.append({
                    'operation_kind': kind.lower(),
                    'name': fm.group(1),
                    'args': args,
                    'output_type': fm.group(3).strip('[]!'),
                    'resolver': rm.group(1).replace('\\\\', '\\') if rm else '',
                    'file': rel(fpath),
                })
    return ops

# ---------------------------------------------------------------------------
# 11. DB Schema
# ---------------------------------------------------------------------------
def extract_db_schema(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'db_schema.xml')
    if not os.path.isfile(fpath):
        return entries
    root = read_xml(fpath)
    if root is None:
        return entries
    for table_el in root.findall('.//table'):
        table_name = table_el.get('name', '')
        columns = []
        for col_el in table_el.findall('column'):
            col_name = col_el.get('name', '')
            col_type = col_el.get(XSI_TYPE, col_el.get('type', ''))
            columns.append(f'{col_name}:{col_type}')
        indexes = [idx.get('referenceId', '') for idx in table_el.findall('index')]
        constraints = [c.get('referenceId', '') for c in table_el.findall('constraint')]
        entries.append({
            'table_name': table_name,
            'engine': table_el.get('engine', 'innodb'),
            'columns': columns,
            'indexes': [i for i in indexes if i],
            'constraints': [c for c in constraints if c],
            'file': rel(fpath),
        })
    return entries

# ---------------------------------------------------------------------------
# 12. Extension Attributes
# ---------------------------------------------------------------------------
def extract_extension_attributes(base):
    entries = []
    fpath = os.path.join(base, 'etc', 'extension_attributes.xml')
    if not os.path.isfile(fpath):
        return entries
    root = read_xml(fpath)
    if root is None:
        return entries
    for ea_el in root.findall('.//extension_attributes'):
        for_class = ea_el.get('for', '')
        for attr_el in ea_el.findall('attribute'):
            entries.append({
                'for': for_class,
                'attribute_code': attr_el.get('code', ''),
                'type': attr_el.get('type', ''),
                'file': rel(fpath),
            })
    return entries

# ---------------------------------------------------------------------------
# 13. User-facing surface (admin config/UI, storefront, emails)
# ---------------------------------------------------------------------------
def extract_user_surface(base):
    out = {}
    # --- admin_config (system.xml enriched with nav labels) ---
    cfg = []
    sfile = os.path.join(base, 'etc', 'adminhtml', 'system.xml')
    root = read_xml(sfile) if os.path.isfile(sfile) else None
    if root is not None:
        for sec in root.findall('.//section'):
            sid = sec.get('id', '')
            slabel = (sec.findtext('label') or '').strip()
            tab = (sec.findtext('tab') or '').strip()
            for grp in sec.findall('.//group'):
                gid = grp.get('id', '')
                glabel = (grp.findtext('label') or '').strip()
                for fld in grp.findall('.//field'):
                    cfg.append({
                        'config_path': f'{sid}/{gid}/{fld.get("id", "")}',
                        'section_label': slabel, 'group_label': glabel, 'tab': tab,
                        'field_label': (fld.findtext('label') or '').strip(),
                        'comment': (fld.findtext('comment') or '').strip(),
                        'file': rel(sfile),
                    })
    if cfg:
        out['admin_config'] = cfg
    # --- admin_ui ---
    ui = {'components': [], 'menu': [], 'acl': [], 'admin_routes': []}
    uidir = os.path.join(base, 'view', 'adminhtml', 'ui_component')
    if os.path.isdir(uidir):
        ui['components'] = [{'name': f[:-4], 'file': rel(os.path.join(uidir, f))}
                            for f in sorted(os.listdir(uidir)) if f.endswith('.xml')]
    menu = os.path.join(base, 'etc', 'adminhtml', 'menu.xml')
    mroot = read_xml(menu) if os.path.isfile(menu) else None
    if mroot is not None:
        for a in mroot.findall('.//add'):
            ui['menu'].append({'id': a.get('id', ''), 'title': a.get('title', ''),
                               'parent': a.get('parent', ''), 'action': a.get('action', ''),
                               'resource': a.get('resource', ''), 'file': rel(menu)})
    acl = os.path.join(base, 'etc', 'acl.xml')
    aroot = read_xml(acl) if os.path.isfile(acl) else None
    if aroot is not None:
        for r in aroot.findall('.//resource'):
            rid = r.get('id', '')
            if rid and rid != 'Magento_Backend::admin':
                ui['acl'].append({'id': rid, 'title': r.get('title', ''), 'file': rel(acl)})
    arts = os.path.join(base, 'etc', 'adminhtml', 'routes.xml')
    arroot = read_xml(arts) if os.path.isfile(arts) else None
    if arroot is not None:
        for r in arroot.findall('.//route'):
            ui['admin_routes'].append({'id': r.get('id', ''), 'frontName': r.get('frontName', ''),
                                       'file': rel(arts)})
    ui = {k: v for k, v in ui.items() if v}
    if ui:
        out['admin_ui'] = ui
    # --- storefront ---
    sf = {'routes': [], 'controllers': [], 'layouts': [], 'templates': []}
    fr = os.path.join(base, 'etc', 'frontend', 'routes.xml')
    frroot = read_xml(fr) if os.path.isfile(fr) else None
    if frroot is not None:
        for r in frroot.findall('.//route'):
            sf['routes'].append({'id': r.get('id', ''), 'frontName': r.get('frontName', ''),
                                 'file': rel(fr)})
    cdir = os.path.join(base, 'Controller')
    if os.path.isdir(cdir):
        for dp, _d, files in os.walk(cdir):
            if f'{os.sep}Adminhtml{os.sep}' in f'{dp}{os.sep}':
                continue
            for fn in files:
                if fn.endswith('.php'):
                    sf['controllers'].append({'class': fn[:-4], 'file': rel(os.path.join(dp, fn))})
    ldir = os.path.join(base, 'view', 'frontend', 'layout')
    if os.path.isdir(ldir):
        sf['layouts'] = [{'handle': f[:-4], 'file': rel(os.path.join(ldir, f))}
                         for f in sorted(os.listdir(ldir)) if f.endswith('.xml')]
    tdir = os.path.join(base, 'view', 'frontend', 'templates')
    if os.path.isdir(tdir):
        for dp, _d, files in os.walk(tdir):
            for fn in files:
                if fn.endswith('.phtml'):
                    sf['templates'].append({'file': rel(os.path.join(dp, fn))})
    sf = {k: v for k, v in sf.items() if v}
    if sf:
        out['storefront'] = sf
    # --- emails ---
    emails = []
    ef = os.path.join(base, 'etc', 'email_templates.xml')
    eroot = read_xml(ef) if os.path.isfile(ef) else None
    if eroot is not None:
        for t in eroot.findall('.//template'):
            emails.append({'id': t.get('id', ''), 'label': t.get('label', ''),
                           'file_attr': t.get('file', ''), 'module': t.get('module', ''),
                           'file': rel(ef)})
    if emails:
        out['emails'] = emails
    return out

# ---------------------------------------------------------------------------
# Run all extractors
# ---------------------------------------------------------------------------
plugins, preferences = extract_plugins_preferences(module_path)
_rest = extract_rest_routes(module_path)
enrich_rest_examples(module_path, _rest)
_rest_warnings = scan_bare_types(module_path, _rest)

surface = {
    'module_path': module_path,
    'surfaces': {
        'api': extract_api(module_path),
        'api_methods': extract_api_methods(module_path),
        'events_observed': extract_events_observed(module_path),
        'events_fired': extract_events_fired(module_path),
        'plugins': plugins,
        'preferences': preferences,
        'cli_commands': extract_cli_commands(module_path),
        'config_paths': extract_config_paths(module_path),
        'cron_jobs': extract_cron_jobs(module_path),
        'rest_routes': _rest,
        'rest_warnings': _rest_warnings,
        'graphql': extract_graphql(module_path),
        'graphql_operations': extract_graphql_operations(module_path),
        'db_schema': extract_db_schema(module_path),
        'extension_attributes': extract_extension_attributes(module_path),
        'user_surface': extract_user_surface(module_path),
    },
}

with open(surface_file, 'w', encoding='utf-8') as fh:
    json.dump(surface, fh, indent=2)
PY
then
    echo "extract-surface: extraction failed" >&2
    [ "$CREATED_SURFACE_FILE" = "1" ] && rm -f "$SURFACE_FILE"
    exit 1
fi

# Print the output path for callers that chain further processing. When this script chose the path,
# the caller owns the file and removes it.
echo "$SURFACE_FILE"
