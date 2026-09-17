#!/usr/bin/env bash
# build-plan.sh — turn a findings document into an ordered, approvable remediation plan.
#
# Read-only: it reads findings, resolves who owns each one, and writes ONE artifact under
# the output root. It never touches the module under review.
#
# The three decisions it makes per finding, in this order:
#   1. Is it waived?          — waivers-lib.sh, keyed on fingerprint. Active → waived[].
#                               EXPIRED → verify_first[], never still suppressed.
#   2. Is it confirmed?       — anything else is evidence to re-check, not work to schedule.
#   3. Who owns it?           — route-finding.sh over the shared matrix. No row → unrouted[],
#                               never a silent default to `fix`.
# Nothing is ever dropped: every ingested finding lands in findings[] with a status, and
# filtered-out ones are recorded in skipped[] with the reason.
#
# Inputs (env vars):
#   TARGET_MODULE    e.g. "Acme_OrderExport" (required)
#   TARGET_PATH      e.g. "app/code/Acme/OrderExport" (required)
#   SCOPE            "module" (default) | "site" | "vendor" | "diff"
#   DOCS_ROOT        default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR       default: {DOCS_ROOT}/remediation
#   INPUT_JSON       findings document, or a directory of them. Default: the newest
#                    {DOCS_ROOT}/audits/*-audit-*.json.
#   WAIVERS_FILE     default: {DOCS_ROOT}/findings/waivers.yml
#                    INPUT_JSON may be a findings JSON, a directory of them, or a .sarif
#                    log (external CI output included). SARIF carries no confidence/
#                    recommendation/verification, so its findings are always held in
#                    verify_first and can never drive an automated patch.
#   RUN_DATE         default: today (UTC). Drives the basename and waiver expiry.
#   SKILL_VERSION    default: 1.0.0
#   MIN_SEVERITY     optional: drop findings below this severity into skipped[].
#   INCLUDE_OWNERS   optional: comma-separated owner allow-list (filters batches).
#   EXCLUDE_OWNERS   optional: comma-separated owner deny-list (filters batches).
#   BREEZE           "1"/"0" to force the Breeze routing predicate; unset = auto-detect
#                    from CONTEXT_FILE's theme.breeze.installed.
#   CONTEXT_FILE     default: .claude/.cache/context.json
#
# Output:
#   {OUTPUT_DIR}/{TARGET_MODULE}-plan-{RUN_DATE}.json (+ .sarif), outputKind=remediation.
#   Stdout echoes the JSON document.
#
# Exit: 0 on success; 2 on a missing prerequisite; 3 when there is no document to triage;
#       4 on a major schemaVersion mismatch (a 2.x document is not ours to interpret).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTX_SCRIPTS="$(cd "${SCRIPT_DIR}/../../context/scripts" 2>/dev/null && pwd)"
if [ -z "${CTX_SCRIPTS:-}" ]; then
    echo "build-plan: context scripts dir not found next to ${SCRIPT_DIR}" >&2
    exit 2
fi

FINDINGS_LIB="${CTX_SCRIPTS}/findings-lib.sh"
WAIVERS_LIB="${CTX_SCRIPTS}/waivers-lib.sh"
ROUTER="${CTX_SCRIPTS}/route-finding.sh"
EMIT_FINDINGS="${CTX_SCRIPTS}/emit-findings.sh"
INJECT_HOOK="${SCRIPT_DIR}/inject-plan-sections.sh"

for _req in "$FINDINGS_LIB" "$WAIVERS_LIB" "$ROUTER" "$EMIT_FINDINGS" "$INJECT_HOOK"; do
    [ -f "$_req" ] || { echo "build-plan: required script not found: $_req" >&2; exit 2; }
done

command -v python3 >/dev/null 2>&1 || { echo "build-plan: python3 required" >&2; exit 2; }

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/remediation}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
SKILL_VERSION="${SKILL_VERSION:-1.0.0}"
WAIVERS_FILE="${WAIVERS_FILE:-${DOCS_ROOT}/findings/waivers.yml}"
MIN_SEVERITY="${MIN_SEVERITY:-}"
INCLUDE_OWNERS="${INCLUDE_OWNERS:-}"
EXCLUDE_OWNERS="${EXCLUDE_OWNERS:-}"
CONTEXT_FILE="${CONTEXT_FILE:-.claude/.cache/context.json}"
BREEZE="${BREEZE:-}"
INPUT_JSON="${INPUT_JSON:-}"

# --- resolve the input document -------------------------------------------------------
# The default path is the one a user actually hits ("triage the last audit"), so it is
# resolved here rather than left to the caller.
if [ -z "$INPUT_JSON" ]; then
    _newest=""
    for _cand in "${DOCS_ROOT}"/audits/*-audit-*.json; do
        [ -e "$_cand" ] || continue
        if [ -z "$_newest" ] || [ "$_cand" -nt "$_newest" ]; then
            _newest="$_cand"
        fi
    done
    INPUT_JSON="$_newest"
fi
if [ -z "$INPUT_JSON" ] || [ ! -e "$INPUT_JSON" ]; then
    echo "build-plan: no findings document to triage — pass INPUT_JSON=<path>, or run" >&2
    echo "build-plan: an audit first so ${DOCS_ROOT}/audits/*-audit-*.json exists." >&2
    exit 3
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
# Everything the CALLER reads is written to OUTPUT_DIR, which is outside TMP_DIR — a path
# printed out of a trap'd directory is gone by the time the caller opens it (v2.2.0 RCA).

# shellcheck source=/dev/null
source "$FINDINGS_LIB"
# shellcheck source=/dev/null
source "$WAIVERS_LIB"

# --- waiver state ---------------------------------------------------------------------
waivers_load "$WAIVERS_FILE"
waivers_check_ignored "$WAIVERS_FILE"

WAIVERS_JSON="${TMP_DIR}/waivers.json"
_wargs=()
if [ "${#WAIVER_VERDICT[@]}" -gt 0 ]; then
    for _fp in "${!WAIVER_VERDICT[@]}"; do
        _wargs+=("$_fp" "$(waivers_status "$_fp" "$RUN_DATE")" "${WAIVER_VERDICT[$_fp]}" \
                 "${WAIVER_REASON[$_fp]}" "${WAIVER_AUTHOR[$_fp]}" "${WAIVER_EXPIRES[$_fp]}")
    done
fi
# The (fp, status, verdict, reason, author, expires) 6-tuples travel via argv, not stdin —
# the heredoc that carries the program already owns stdin.
python3 - ${_wargs[@]+"${_wargs[@]}"} > "$WAIVERS_JSON" <<'PY'
import json
import sys

a = sys.argv[1:]
out = {}
for i in range(0, len(a) - 5, 6):
    out[a[i]] = {
        "status": a[i + 1], "verdict": a[i + 2], "reason": a[i + 3],
        "author": a[i + 4], "expires": a[i + 5],
    }
print(json.dumps(out, indent=2))
PY

# --- ingest, gate, route, batch -------------------------------------------------------
PLAN_FINDINGS="${TMP_DIR}/plan-findings.json"
PLAN_SECTIONS="${TMP_DIR}/plan-sections.json"
SKIPPED_FILE="${TMP_DIR}/skipped.json"
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
TOOLS_FILE="${TMP_DIR}/tools.json"
FINGERPRINTS="${TMP_DIR}/fingerprints.txt"

INPUT_JSON="$INPUT_JSON" WAIVERS_JSON="$WAIVERS_JSON" ROUTER="$ROUTER" \
FINDINGS_LIB="$FINDINGS_LIB" RUN_DATE="$RUN_DATE" BREEZE="$BREEZE" \
CONTEXT_FILE="$CONTEXT_FILE" MIN_SEVERITY="$MIN_SEVERITY" \
INCLUDE_OWNERS="$INCLUDE_OWNERS" EXCLUDE_OWNERS="$EXCLUDE_OWNERS" \
PLAN_FINDINGS="$PLAN_FINDINGS" PLAN_SECTIONS="$PLAN_SECTIONS" \
SKIPPED_FILE="$SKIPPED_FILE" SCANNER_ERRORS_FILE="$SCANNER_ERRORS_FILE" \
TOOLS_FILE="$TOOLS_FILE" FINGERPRINTS="$FINGERPRINTS" \
python3 <<'PY'
import glob
import json
import os
import subprocess
import sys

SUPPORTED_MAJOR, SUPPORTED_MINOR = 1, 1

SEV_RANK = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}

# Batch order is a DEPENDENCY order, not a priority order:
#   upgrade rewrites call sites the later batches would otherwise patch twice;
#   i18n runs once every user-facing string the run will produce exists;
#   test-generate writes tests against final code;
#   lint runs LAST so it formats everything this run produced — first would re-churn.
BATCH_ORDER = [
    "upgrade", "fix",
    "extension-point", "indexer", "message-queue", "webapi", "graphql",
    "admin-form", "admin-listing", "system-config", "data-migration", "feature", "inline",
    "frontend", "breeze-adapt",
    "i18n", "test-generate", "lint", "docs",
]
# An owner the list does not name is structural work by default — it sorts with the
# specialist generators rather than ahead of `upgrade` or behind `lint`.
STRUCTURAL_RANK = BATCH_ORDER.index("extension-point")

# A batch is ONE approval, and an approval means something different for each gate, so a
# batch never mixes them: cheapest and safest first.
GATE_RANK = {"auto": 0, "batch": 1, "manual": 2}

env = os.environ
router = env["ROUTER"]
lib = env["FINDINGS_LIB"]
run_date = env["RUN_DATE"]
min_sev = env.get("MIN_SEVERITY", "").strip().lower()
include = {o.strip() for o in env.get("INCLUDE_OWNERS", "").split(",") if o.strip()}
exclude = {o.strip() for o in env.get("EXCLUDE_OWNERS", "").split(",") if o.strip()}

scanner_errors = []
skipped = []


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        scanner_errors.append({"scanner": "triage-ingest",
                               "stderr": f"failed to read {path}: {exc}"})
        return default


waivers = read_json(env["WAIVERS_JSON"], {})

# --- breeze predicate -----------------------------------------------------------------
raw_breeze = env.get("BREEZE", "").strip()
if raw_breeze in ("1", "0"):
    breeze = raw_breeze == "1"
else:
    ctx = {}
    ctx_path = env.get("CONTEXT_FILE", "")
    if ctx_path and os.path.exists(ctx_path):
        try:
            with open(ctx_path, encoding="utf-8") as fh:
                ctx = json.load(fh)
        except (OSError, ValueError):
            ctx = {}
    theme = ctx.get("theme") or {}
    breeze = bool((theme.get("breeze") or {}).get("installed"))

# --- ingest ---------------------------------------------------------------------------
target = env["INPUT_JSON"]
if os.path.isdir(target):
    paths = sorted(glob.glob(os.path.join(target, "*.json")))
    # A .sarif is only read when it has no .json sibling. The JSON is strictly richer
    # (confidence, recommendation, verification), and ingesting both would make which
    # one wins depend on dict ordering.
    seen = {os.path.splitext(p)[0] for p in paths}
    paths += sorted(p for p in glob.glob(os.path.join(target, "*.sarif"))
                    if os.path.splitext(p)[0] not in seen)
else:
    paths = [target]
if not paths:
    sys.stderr.write(f"build-plan: no *.json documents under {target}\n")
    sys.exit(3)


def fingerprint_of(producer, f):
    """Reuse findings-lib.sh's finding_fingerprint for a pre-1.1 document.

    Shelling out to the ONE bash implementation is deliberate: a second normalizer
    written here would diverge from the emitter's on exactly the whitespace and
    trailing-separator cases the fingerprint exists to survive.
    """
    ev = (f.get("evidence") or [{}])[0]
    proc = subprocess.run(
        ["bash", "-c",
         'source "$1"; finding_fingerprint "$2" "$3" "$4" "$5" "$6" "$7"',
         "build-plan", lib, producer,
         f.get("category", ""), f.get("subcategory", "") or "",
         f.get("title", ""), ev.get("file", ""), ev.get("snippet", "") or ""],
        capture_output=True, text=True, stdin=subprocess.DEVNULL,
    )
    return proc.stdout.strip()


SARIF_LEVEL_TO_SEVERITY = {"error": "high", "warning": "medium", "note": "low",
                            "none": "info"}


def sarif_to_findings_doc(doc, path):
    """Normalise a SARIF 2.1.0 log into the findings-schema shape this builder speaks.

    SARIF is a lossy carrier by design: it has no `confidence`, `recommendation` or
    `verification`. Every finding read from one is therefore forced to
    `confidence: needs-triage`, which the gate below holds in `verify_first` — a SARIF
    finding can never drive an automated patch, only a reviewed one. That is the point:
    a CI scanner's output is evidence, not a diagnosis.

    Our own SARIF round-trips losslessly enough to stay identifiable: the emitter writes
    `partialFingerprints` and stores the finding category in the rule's `name`.
    """
    runs = doc.get("runs")
    if not isinstance(runs, list) or not runs:
        return None
    findings = []
    driver_names = []
    for run in runs:
        if not isinstance(run, dict):
            continue
        driver = ((run.get("tool") or {}).get("driver") or {})
        driver_name = driver.get("name", "") or ""
        driver_names.append(driver_name)
        # ruleId -> category, via the rule `name` our emitter writes.
        rule_category = {}
        for rule in driver.get("rules") or []:
            if isinstance(rule, dict) and rule.get("id"):
                rule_category[rule["id"]] = rule.get("name", "") or ""
        for res in run.get("results") or []:
            if not isinstance(res, dict):
                continue
            loc = {}
            for location in res.get("locations") or []:
                phys = (location or {}).get("physicalLocation") or {}
                art = phys.get("artifactLocation") or {}
                region = phys.get("region") or {}
                loc = {"file": art.get("uri", ""), "line": region.get("startLine", 1)}
                break
            rule_id = res.get("ruleId", "") or ""
            text = ((res.get("message") or {}).get("text") or "").strip()
            title = text.splitlines()[0] if text else ""
            findings.append({
                "id": rule_id or f"sarif-{len(findings) + 1}",
                "fingerprint": (res.get("partialFingerprints") or {}).get(
                    "m2FindingFingerprint/v1", ""),
                "severity": SARIF_LEVEL_TO_SEVERITY.get(res.get("level", "note"), "low"),
                "category": rule_category.get(rule_id, ""),
                "title": title,
                "evidence": [loc] if loc else [],
                "confidence": "needs-triage",
                "tags": ["producer:" + driver_name] if driver_name else [],
            })
    return {
        "schemaVersion": "1.1",
        "skill": driver_names[0] if driver_names else "",
        "outputKind": "sarif",
        "findings": findings,
    }


def producer_of(f, doc_skill):
    for tag in f.get("tags") or []:
        if isinstance(tag, str) and tag.startswith("producer:"):
            return tag.split(":", 1)[1]
    return doc_skill


order = []          # fingerprints, in first-seen order
items = {}          # fingerprint -> {"finding": …, "producers": [...], "source_id": …}
inputs = []

for path in paths:
    doc = read_json(path, None)
    if not isinstance(doc, dict):
        continue
    if path.endswith(".sarif"):
        doc = sarif_to_findings_doc(doc, path)
        if doc is None:
            scanner_errors.append({"scanner": "triage-ingest",
                                   "stderr": f"{path}: not a readable SARIF log; skipped"})
            continue
    raw_ver = str(doc.get("schemaVersion", "1.0"))
    try:
        major, minor = (int(p) for p in raw_ver.split(".")[:2])
    except ValueError:
        major, minor = SUPPORTED_MAJOR, SUPPORTED_MINOR
        scanner_errors.append({"scanner": "triage-ingest",
                               "stderr": f"{path}: unparseable schemaVersion {raw_ver!r}, "
                                         "assuming 1.1"})
    if major != SUPPORTED_MAJOR:
        sys.stderr.write(
            f"build-plan: {path} is findings schema {raw_ver}; this builder speaks "
            f"{SUPPORTED_MAJOR}.{SUPPORTED_MINOR}. A major-version mismatch is a hard "
            "error — the field semantics are not ours to guess.\n")
        sys.exit(4)
    if minor > SUPPORTED_MINOR:
        msg = (f"{path}: schema {raw_ver} is newer than {SUPPORTED_MAJOR}."
               f"{SUPPORTED_MINOR}; unknown fields are ignored.")
        sys.stderr.write("build-plan: " + msg + "\n")
        scanner_errors.append({"scanner": "triage-ingest", "stderr": msg})

    doc_skill = doc.get("skill", "")
    inputs.append({"path": path, "skill": doc_skill, "schemaVersion": raw_ver,
                   "outputKind": doc.get("outputKind", ""),
                   "findings": len(doc.get("findings") or [])})

    for f in doc.get("findings") or []:
        if not isinstance(f, dict):
            continue
        producer = producer_of(f, doc_skill)
        # An external SARIF carries no partialFingerprints, so identity is recomputed from
        # what it does carry. The snippet is absent there, so such a fingerprint will NOT
        # match one derived from the richer JSON — waivers written against a JSON report do
        # not transfer to a foreign SARIF, and that is honest rather than silently wrong.
        fp = f.get("fingerprint") or fingerprint_of(producer, f)
        if not fp:
            scanner_errors.append({"scanner": "triage-ingest",
                                   "stderr": f"{path}: could not fingerprint finding "
                                             f"{f.get('id', '<no id>')!r}; skipped"})
            continue
        if fp in items:
            # Dedupe across documents: keep the highest severity, remember every
            # dimension that raised it.
            prev = items[fp]
            if SEV_RANK.get(f.get("severity", "info"), 0) > \
               SEV_RANK.get(prev["finding"].get("severity", "info"), 0):
                prev["finding"] = f
            if producer not in prev["producers"]:
                prev["producers"].append(producer)
            continue
        items[fp] = {"finding": f, "producers": [producer],
                     "source_id": f.get("id", "")}
        order.append(fp)

# Every ingested fingerprint, filtered or not — a waiver for a finding this run filtered
# out is still a LIVE waiver, not a stale one.
with open(env["FINGERPRINTS"], "w", encoding="utf-8") as fh:
    for fp in order:
        fh.write(fp + "\n")


def route(producer, f):
    args = [router, f"--skill={producer}", f"--category={f.get('category', '')}"]
    if f.get("subcategory"):
        args.append(f"--subcategory={f['subcategory']}")
    if f.get("severity"):
        args.append(f"--severity={f['severity']}")
    ev = (f.get("evidence") or [{}])[0]
    if ev.get("file"):
        args.append(f"--file={ev['file']}")
    if breeze:
        args.append("--breeze")
    proc = subprocess.run(["bash"] + args, capture_output=True, text=True,
                          stdin=subprocess.DEVNULL)
    parts = proc.stdout.rstrip("\n").split("\t")
    if len(parts) != 3:
        err = proc.stderr.strip() or "resolver produced no TSV row"
        scanner_errors.append({"scanner": "route-finding.sh",
                               "stderr": f"{producer}/{f.get('category', '')}: {err}"})
        return "unrouted", "manual", f"resolver failed for {producer}/{f.get('category', '')}"
    return parts[0], parts[1], parts[2]


routed = []
waived_bucket = []
verify_bucket = []
unrouted_bucket = []

for fp in order:
    entry = items[fp]
    f = entry["finding"]
    producer = entry["producers"][0]
    sev = f.get("severity", "info")
    ev = (f.get("evidence") or [{}])[0]
    file_ = ev.get("file", "")

    if min_sev and SEV_RANK.get(sev, 0) < SEV_RANK.get(min_sev, 0):
        skipped.append({"check": f"{producer}/{f.get('category', '')}", "fingerprint": fp,
                        "reason": f"severity {sev} is below the requested minimum {min_sev}"})
        continue

    record = dict(f)
    record["fingerprint"] = fp
    record["source_finding"] = {"id": entry["source_id"], "producer": producer}
    if len(entry["producers"]) > 1:
        record["producers"] = entry["producers"]

    w = waivers.get(fp)
    if w and w.get("status") == "active":
        record.update(owner="none", gate="manual", status="waived",
                      routing_rationale=f"waived ({w.get('verdict', '')}): "
                                        f"{w.get('reason', '')}")
        waived_bucket.append({
            "fingerprint": fp, "id": entry["source_id"], "title": f.get("title", ""),
            "category": f.get("category", ""), "severity": sev, "file": file_,
            "verdict": w.get("verdict", ""), "reason": w.get("reason", ""),
            "author": w.get("author", ""), "expires": w.get("expires", ""),
        })
        routed.append(record)
        continue

    if w and w.get("status") == "expired":
        note = f"waiver expired {w.get('expires', '')}"
    elif (f.get("confidence") or "confirmed") != "confirmed":
        note = f"confidence is {f.get('confidence')}, not confirmed"
    else:
        note = ""

    if note:
        record.update(owner="none", gate="manual", status="verify-first",
                      routing_rationale=f"held for verification: {note}")
        verify_bucket.append({
            "fingerprint": fp, "id": entry["source_id"], "title": f.get("title", ""),
            "category": f.get("category", ""), "severity": sev, "file": file_,
            "note": note,
        })
        routed.append(record)
        continue

    owner, gate, rationale = route(producer, f)
    if owner == "unrouted":
        record.update(owner="unrouted", gate="manual", status="unrouted",
                      routing_rationale=rationale)
        unrouted_bucket.append({
            "fingerprint": fp, "id": entry["source_id"], "title": f.get("title", ""),
            "category": f.get("category", ""), "severity": sev, "file": file_,
            "producer": producer, "reason": rationale,
        })
        routed.append(record)
        continue

    if (include and owner not in include) or owner in exclude:
        skipped.append({"check": f"{producer}/{f.get('category', '')}", "fingerprint": fp,
                        "reason": f"owner '{owner}' excluded by the requested owner filter"})
        continue

    record.update(owner=owner, gate=gate, status="routable",
                  routing_rationale=rationale)
    routed.append(record)

# --- batches --------------------------------------------------------------------------
# `none` is the matrix's way of saying "no skill fixes this" — it is a human action, so it
# is reported but never scheduled. Batching it would promise an execution nobody can run.
groups = {}
for record in routed:
    if record["status"] != "routable" or record["owner"] == "none":
        continue
    groups.setdefault((record["owner"], record["gate"]), []).append(record)


def group_key(item):
    owner, gate = item
    rank = BATCH_ORDER.index(owner) if owner in BATCH_ORDER else STRUCTURAL_RANK
    return rank, GATE_RANK.get(gate, 1), owner


batches = []
for seq, key in enumerate(sorted(groups, key=group_key), start=1):
    owner, gate = key
    members = sorted(groups[key],
                     key=lambda r: (-SEV_RANK.get(r.get("severity", "info"), 0),
                                    r.get("title", "")))
    for record in members:
        record["batch"] = seq
    batches.append({"seq": seq, "owner": owner, "gate": gate,
                    "fingerprints": [r["fingerprint"] for r in members]})

STATUS_ORDER = {"routable": 0, "verify-first": 1, "waived": 2, "unrouted": 3}
routed.sort(key=lambda r: (STATUS_ORDER.get(r["status"], 9), r.get("batch", 0),
                           -SEV_RANK.get(r.get("severity", "info"), 0),
                           r.get("title", "")))
for seq, record in enumerate(routed, start=1):
    record["id"] = f"triage-{run_date}-{seq:03d}"


def dump(path, payload):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


dump(env["PLAN_FINDINGS"], routed)
dump(env["PLAN_SECTIONS"], {
    "inputs": inputs,
    "batches": batches,
    "waived": waived_bucket,
    "verify_first": verify_bucket,
    "unrouted": unrouted_bucket,
})
dump(env["SKIPPED_FILE"], skipped)
dump(env["SCANNER_ERRORS_FILE"], scanner_errors)
dump(env["TOOLS_FILE"], {"route-finding.sh": "executed", "waivers-lib.sh": "executed"})
PY
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "build-plan: plan assembly failed (exit $RC)" >&2
    exit "$RC"
fi

# --- stale waivers --------------------------------------------------------------------
# A waiver matching nothing in this run is dead weight; report it so it gets pruned.
_fps=()
if [ -s "$FINGERPRINTS" ]; then
    while IFS= read -r _line; do
        [ -n "$_line" ] && _fps+=("$_line")
    done < "$FINGERPRINTS"
fi
_stale=()
while IFS= read -r _s; do
    [ -n "$_s" ] && _stale+=("$_s")
done < <(waivers_stale ${_fps[@]+"${_fps[@]}"})

python3 - "$PLAN_SECTIONS" ${_stale[@]+"${_stale[@]}"} <<'PY'
import json
import sys

path, stale = sys.argv[1], sys.argv[2:]
with open(path, encoding="utf-8") as fh:
    doc = json.load(fh)
doc["stale_waivers"] = stale
with open(path, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY

# --- emit -----------------------------------------------------------------------------
export FINDINGS_FILE="$PLAN_FINDINGS"
export SCANNER_ERRORS_FILE SKIPPED_FILE TOOLS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export MODE="full"
export SKILL_NAME="triage"
export SKILL_VERSION
export OUTPUT_KIND="remediation"
export SKILL_VERSIONS_JSON="[\"triage@${SKILL_VERSION}\",\"context@${FINDINGS_LIB_CONTEXT_VERSION}\"]"
export TRIAGE_PLAN_SECTIONS="$PLAN_SECTIONS"

BASENAME_KIND="plan" DATE="$RUN_DATE" POST_JSON_HOOK="$INJECT_HOOK" bash "$EMIT_FINDINGS"
