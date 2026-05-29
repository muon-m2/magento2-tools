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
    return {
        'id': f.get('id'),
        'name': f.get('category', 'uncategorized'),
        'shortDescription': {'text': f.get('title', '')},
        'fullDescription': {'text': f.get('description') or f.get('title', '')},
        'defaultConfiguration': {'level': SEVERITY_TO_LEVEL.get(f.get('severity', 'info'), 'note')},
        'helpUri': None,
    }


def result_from_finding(f: dict) -> dict:
    return {
        'ruleId': f.get('id'),
        'level': SEVERITY_TO_LEVEL.get(f.get('severity', 'info'), 'note'),
        'message': {'text': f.get('title', '')},
        'locations': [physical_location(e) for e in f.get('evidence', [])] or [
            physical_location({'file': 'unknown', 'line': 1})
        ],
    }


with open(os.environ['JSON_FILE'], encoding='utf-8') as fh:
    doc = json.load(fh)

findings = doc.get('findings', [])

sarif = {
    '$schema': 'https://docs.oasis-open.org/sarif/sarif/v2.1.0/cos02/schemas/sarif-schema-2.1.0.json',
    'version': '2.1.0',
    'runs': [
        {
            'tool': {
                'driver': {
                    'name': doc.get('skill', 'magento2-module-review'),
                    'version': doc.get('skillVersion', '0.0.0'),
                    'informationUri': 'https://github.com/magento/magento2',
                    'rules': [rule_from_finding(f) for f in findings],
                }
            },
            'invocations': [
                {'executionSuccessful': True, 'endTimeUtc': doc.get('runAt')}
            ],
            'results': [result_from_finding(f) for f in findings],
        }
    ],
}

print(json.dumps(sarif, indent=2, ensure_ascii=False))
PY

echo "emit-sarif: wrote $OUTPUT_FILE" >&2
