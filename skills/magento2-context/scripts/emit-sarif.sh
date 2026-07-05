#!/usr/bin/env bash
# emit-sarif.sh — convert a findings JSON document to SARIF 2.1.0.
#
# Inputs:
#   $1          Path to the JSON document produced by emit-json.sh (required)
#   OUTPUT_DIR  default: same directory as the JSON file
#
# Output:
#   Writes SARIF to {OUTPUT_DIR}/<basename of JSON>.sarif and prints it to stdout.

set -euo pipefail

JSON_FILE="${1:?usage: emit-sarif.sh <json-file>}"
[ -f "$JSON_FILE" ] || { echo "emit-sarif: file not found: $JSON_FILE" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "emit-sarif: python3 required" >&2
    exit 3
fi

OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$JSON_FILE")}"
BASE="$(basename "$JSON_FILE" .json)"
OUTPUT_FILE="${OUTPUT_DIR}/${BASE}.sarif"

JSON_FILE="$JSON_FILE" OUTPUT_FILE="$OUTPUT_FILE" python3 <<'PY' | tee "$OUTPUT_FILE"
import json
import os
import sys

SEVERITY_TO_LEVEL = {
    'critical': 'error',
    'high': 'error',
    'medium': 'warning',
    'low': 'note',
    'info': 'note',
}


def physical_location(evidence: dict) -> dict:
    region = {'startLine': evidence.get('line') or 1}
    if evidence.get('endLine'):
        region['endLine'] = evidence['endLine']
    return {
        'physicalLocation': {
            'artifactLocation': {'uri': evidence.get('file', 'unknown')},
            'region': region,
        }
    }


def rule_from_finding(f: dict) -> dict:
    rule = {
        'id': f.get('id'),
        'name': f.get('category', 'uncategorized'),
        'shortDescription': {'text': f.get('title', '')},
        'fullDescription': {'text': f.get('description') or f.get('title', '')},
        'defaultConfiguration': {'level': SEVERITY_TO_LEVEL.get(f.get('severity', 'info'), 'note')},
    }
    # SARIF requires helpUri to be a valid URI string when present; omit it
    # entirely (rather than emitting null) when the finding carries no URL.
    help_uri = f.get('bulletin_url') or f.get('helpUri')
    if isinstance(help_uri, str) and help_uri:
        rule['helpUri'] = help_uri
    # CWE -> SARIF taxa relationship (taxonomies declared at run level).
    cwe = f.get('cwe')
    if isinstance(cwe, str) and cwe:
        rule['relationships'] = [
            {
                'target': {
                    'id': cwe,
                    'toolComponent': {'name': 'CWE'},
                },
                'kinds': ['superset'],
            }
        ]
    return rule


def result_from_finding(f: dict) -> dict:
    result = {
        'ruleId': f.get('id'),
        'level': SEVERITY_TO_LEVEL.get(f.get('severity', 'info'), 'note'),
        'message': {'text': f.get('title', '')},
        'locations': [physical_location(e) for e in f.get('evidence', [])] or [
            physical_location({'file': 'unknown', 'line': 1})
        ],
    }
    cwe = f.get('cwe')
    if isinstance(cwe, str) and cwe:
        result['taxa'] = [
            {
                'id': cwe,
                'toolComponent': {'name': 'CWE'},
            }
        ]
    return result


def cwe_taxonomy(findings: list) -> list:
    """Build the SARIF taxonomies[] block from finding `cwe` fields.

    Returns an empty list when no finding carries a CWE so the key can be
    omitted (SARIF requires taxa[].id to be a non-null string when present).
    """
    seen = []
    for f in findings:
        cwe = f.get('cwe')
        if isinstance(cwe, str) and cwe and cwe not in seen:
            seen.append(cwe)
    if not seen:
        return []
    return [
        {
            'name': 'CWE',
            'organization': 'MITRE',
            'shortDescription': {'text': 'Common Weakness Enumeration'},
            'informationUri': 'https://cwe.mitre.org/',
            'taxa': [{'id': cwe} for cwe in seen],
        }
    ]


with open(os.environ['JSON_FILE'], encoding='utf-8') as fh:
    doc = json.load(fh)

findings = doc.get('findings', [])

driver = {
    'name': doc.get('skill', 'magento2-module-review'),
    'version': doc.get('skillVersion', '0.0.0'),
    # Attribute the tool to this plugin, not Magento core.
    'informationUri': 'https://github.com/muon-m2/magento2-tools',
    'rules': [rule_from_finding(f) for f in findings],
}

run = {
    'tool': {'driver': driver},
    'invocations': [{'executionSuccessful': True}],
    'results': [result_from_finding(f) for f in findings],
}

# SARIF requires endTimeUtc to be a date-time string when present; omit it
# rather than emitting null when the document has no runAt timestamp.
run_at = doc.get('runAt')
if isinstance(run_at, str) and run_at:
    run['invocations'][0]['endTimeUtc'] = run_at

taxonomies = cwe_taxonomy(findings)
if taxonomies:
    run['taxonomies'] = taxonomies

sarif = {
    '$schema': 'https://docs.oasis-open.org/sarif/sarif/v2.1.0/cos02/schemas/sarif-schema-2.1.0.json',
    'version': '2.1.0',
    'runs': [run],
}

print(json.dumps(sarif, indent=2, ensure_ascii=False))
PY

echo "emit-sarif: wrote $OUTPUT_FILE" >&2
