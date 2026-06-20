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
# Output: JSON written to SURFACE_FILE (default: a temp file whose path is printed
# to stdout for callers that chain further processing).

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
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ -z "$SURFACE_FILE" ]; then
    SURFACE_FILE="${TMP_DIR}/surface.json"
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
    r'public\s+function\s+(\w+)\s*\(([^)]*)\)\s*:\s*\??([\\\w\[\]]+)'
)

def extract_api_methods(base):
    """Public method signatures of @api interfaces/classes."""
    entries = []
    api_files = set()
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
# 9. REST routes
# ---------------------------------------------------------------------------
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
        entries.append({
            'method': route_el.get('method', ''),
            'url': route_el.get('url', ''),
            'service_class': service_el.get('class', '') if service_el is not None else '',
            'service_method': service_el.get('method', '') if service_el is not None else '',
            'auth': ', '.join(auth_scopes),
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
    field_re = re.compile(r'^\s+(\w+)\s*[:(]')
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
                current_fields.append(fm.group(1))
    if current_name:
        entries.append({
            'kind': current_kind,
            'name': current_name,
            'fields': current_fields,
            'file': rel(fpath),
        })
    return entries

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
# Run all extractors
# ---------------------------------------------------------------------------
plugins, preferences = extract_plugins_preferences(module_path)

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
        'rest_routes': extract_rest_routes(module_path),
        'graphql': extract_graphql(module_path),
        'db_schema': extract_db_schema(module_path),
        'extension_attributes': extract_extension_attributes(module_path),
    },
}

with open(surface_file, 'w', encoding='utf-8') as fh:
    json.dump(surface, fh, indent=2)
PY
then
    echo "extract-surface: extraction failed" >&2
    exit 1
fi

# Print the output path for callers that chain further processing.
echo "$SURFACE_FILE"
