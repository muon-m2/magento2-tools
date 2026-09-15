#!/usr/bin/env bash
# Runs the read-only surface extractor against the fixture module and asserts the
# surface-JSON contract: existing keys plus the multi-doc expansion keys.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

FIXTURE="tests/fixtures/docs-generate/Acme/Sample"
SCRIPT="skills/docs/scripts/extract-surface.sh"
[ -d "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

# The contract assertions below read a pinned output path.
_SF="$(mktemp /tmp/surface-test-XXXXXX.json)"
_DEFAULT_SF=""
trap 'rm -f "$_SF" ${_DEFAULT_SF:+"$_DEFAULT_SF"}' EXIT

# The DEFAULT output path first — SURFACE_FILE unset, which is how docs/SKILL.md Phase 2 runs it.
# The extractor used to create that file inside its own temp dir and print its path, and its EXIT
# trap deleted the dir before the caller could read it. Every other assertion here pins
# SURFACE_FILE, which is exactly why that shipped unnoticed.
_DEFAULT_SF="$(env -u SURFACE_FILE MODULE_PATH="$FIXTURE" bash "$SCRIPT")" \
    || { echo "FAIL: extractor errored without SURFACE_FILE"; exit 1; }
[ -f "$_DEFAULT_SF" ] || { echo "FAIL: printed surface path does not exist once the extractor exits: $_DEFAULT_SF"; exit 1; }
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$_DEFAULT_SF" \
    || { echo "FAIL: default surface file is not valid JSON: $_DEFAULT_SF"; exit 1; }

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
need(len(s["rest_routes"]) == 6, "expected 6 REST routes")
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
up = [r for r in s["rest_routes"] if r["service_method"] == "upsert"][0]
need(isinstance(up.get("request_shape"), dict),
     "union DTO param (SampleInterface|null) must resolve to a DTO object, not a string")
um = [m for m in s["api_methods"] if m["method"] == "upsert"]
need(um and "|" in um[0]["return_type"],
     "api_methods must capture the full union return type verbatim")
# --- API description artifacts: route metadata the spec formats need ---
need(g["url_template"] == "/V1/acme-sample/{id}", ":param not rewritten to {param}")
need(g["path_params"] == [{"name": "id", "type": "integer"}],
     "path param not typed from the service-method signature")
need(g["auth_kind"] == "acl" and g["acl_resources"] == ["Acme_Sample::view"],
     "ACL route not classified")
me = [r for r in s["rest_routes"] if r["service_method"] == "getForCurrentCustomer"][0]
need(me["auth_kind"] == "self" and me["acl_resources"] == [], "self route not classified")
need(ext[0]["auth_kind"] == "anonymous", "anonymous route not classified")
need(g["response_schema"]["type"] == "object", "response_schema not an object node")
need(g["response_schema"]["title"] == "Sample", "DTO schema carries no component title")
need(g["response_schema"]["properties"]["entity_id"] == {"type": "integer"},
     "int getter not typed as integer in the schema walk")
need(g["response_schema"]["properties"]["store"] == {"type": "string"},
     "out-of-module getter type should degrade to {type: string}")
need(p["request_schema"]["title"] == "Sample", "request_schema not built from the DTO param")
up2 = [r for r in s["rest_routes"] if r["service_method"] == "upsert"][0]
need(up2["response_schema"].get("nullable") is True,
     "union with null must mark the schema nullable")
gl = [r for r in s["rest_routes"] if r["service_method"] == "getList"][0]
need(gl["is_search_criteria"] is True, "SearchCriteria param not flagged")
need(gl["request_schema"] is None and gl["request_shape"] is None,
     "a SearchCriteria route must not carry a request body")
need(gl["response_schema"]["properties"]["items"]["type"] == "array",
     "`array` + `@return Foo[]` docblock must resolve to a typed array")
need(gl["response_schema"]["properties"]["items"]["items"]["title"] == "Sample",
     "collection element type lost")
# --- bare `array` preflight (spec section 8) ---
need("rest_warnings" in s, "missing rest_warnings key")
bare = [w for w in s["rest_warnings"] if w["annotation"] == "@param array $context"]
need(bare, "bare `array` annotation not reported")
need(bare[0]["file"] == "Api/Data/SampleInterface.php" and bare[0]["line"] > 0,
     "bare-array warning must name file and line")
need("TypeProcessor" in bare[0]["message"], "bare-array warning lacks the failure explanation")
need(not [w for w in s["rest_warnings"] if "getItems" in w["annotation"]],
     "`array` typed by a `@return Foo[]` docblock must NOT warn")
print("PASS")
PY
