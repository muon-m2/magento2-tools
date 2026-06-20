#!/usr/bin/env bash
# Runs the read-only surface extractor against the fixture module and asserts the
# surface-JSON contract: existing keys plus the multi-doc expansion keys.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

FIXTURE="tests/fixtures/docs-generate/Acme/Sample"
SCRIPT="skills/magento2-docs-generate/scripts/extract-surface.sh"
[ -d "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

# Pre-create a stable output path so the extractor does not place the JSON inside
# its own temp dir (which it removes on EXIT before we can read it).
_SF="$(mktemp /tmp/surface-test-XXXXXX.json)"
trap 'rm -f "$_SF"' EXIT

JSON_PATH="$(MODULE_PATH="$FIXTURE" SURFACE_FILE="$_SF" bash "$SCRIPT")" || { echo "FAIL: extractor errored"; exit 1; }

python3 - "$JSON_PATH" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["surfaces"]
def need(cond, msg):
    if not cond:
        print("FAIL:", msg); sys.exit(1)
# existing-key regression guard
for k in ("api","events_observed","plugins","rest_routes","graphql","db_schema"):
    need(k in s, f"missing existing key {k}")
need(len(s["rest_routes"]) == 3, "expected 3 REST routes")
need("api_methods" in s, "missing api_methods key")
ams = [m for m in s["api_methods"] if m["method"] == "getById"]
need(ams, "getById not extracted as an api method")
need(ams[0]["return_type"].endswith("SampleInterface"), "getById return type not captured")
g = [r for r in s["rest_routes"] if r["service_method"] == "getById"][0]
need(isinstance(g.get("response_shape"), dict), "getById response_shape not a DTO object")
need(g["response_shape"].get("customer_email") == "string", "DTO field not skeletonized")
need(g["response_shape"].get("active") is True, "bool field not skeletonized")
need(any("NoSuchEntity" in t for t in g.get("throws", [])), "throws not captured")
p = [r for r in s["rest_routes"] if r["service_method"] == "save"][0]
need(isinstance(p.get("request_shape"), dict), "save request_shape not built from DTO param")
need(not p.get("throws"), "save must have empty throws (method-scoped @throws)")
need("graphql_operations" in s, "missing graphql_operations key")
q = [o for o in s["graphql_operations"] if o["name"] == "acmeSample"]
need(q and q[0]["operation_kind"] == "query", "query op not extracted")
need(q[0]["output_type"] == "Sample", "output_type not captured")
need(any(a["name"] == "id" for a in q[0]["args"]), "query args not captured")
st = [t for t in s["graphql"] if t["name"] == "Sample"][0]
need(isinstance(st["fields"][0], dict) and "type" in st["fields"][0], "graphql field types not captured")
us = s.get("user_surface", {})
need("admin_config" in us and us["admin_config"][0]["config_path"] == "acme_sample/general/enabled",
     "admin_config not extracted")
need(us["admin_config"][0]["group_label"] == "General", "config nav labels not captured")
need(us.get("admin_ui", {}).get("menu"), "admin menu not extracted")
need(us.get("admin_ui", {}).get("acl"), "acl not extracted")
need(us.get("storefront", {}).get("routes"), "storefront route not extracted")
need(us.get("emails") and us["emails"][0]["id"] == "acme_sample_notify", "email template not extracted")
# --- negative paths: graceful degradation when resolution leaves the module ---
need(g["response_shape"].get("store") == "string",
     'out-of-module DTO getter type should degrade to "string"')
ext = [r for r in s["rest_routes"] if "external" in r["url"]]
need(ext, "external (out-of-module-service) route not present")
need(ext[0].get("response_shape") is None,
     "out-of-module service class should yield null response_shape")
need(ext[0].get("request_shape") is None,
     "out-of-module service class should yield null request_shape")
print("PASS")
PY
