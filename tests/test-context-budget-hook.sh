#!/usr/bin/env bash
# test-context-budget-hook.sh — the warn-only context-budget hook (hooks/context-budget.sh).
#
# Feeds synthetic hook payloads + transcripts and asserts: it warns (systemMessage + model
# additionalContext) only when a magento2-tools entry point starts in a conversation above the
# threshold; it never blocks (always exit 0); and it fails open — silent — on every uncertain
# branch (no transcript, malformed JSONL, a fresh compaction, a foreign prompt or skill).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not available"; exit 77; }

HOOK=hooks/context-budget.sh
[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

FAIL=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# transcript <file> <ctx-tokens> [extra-jsonl-line] — one user line, one assistant line whose
# usage sums to <ctx-tokens> (split across input / cache read / cache write), optional tail line.
transcript() {
    python3 - "$1" "$2" "${3:-}" <<'PY'
import json, sys
path, ctx, extra = sys.argv[1], int(sys.argv[2]), sys.argv[3]
rows = [
    {"type": "user", "message": {"role": "user", "content": "hi"}},
    {"type": "assistant", "isSidechain": False, "message": {"model": "m", "usage": {
        "input_tokens": 10, "cache_read_input_tokens": ctx - 110, "cache_creation_input_tokens": 100,
        "output_tokens": 5}}},
]
with open(path, "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
    if extra:
        f.write(extra + "\n")
PY
}

prompt_payload() { # transcript prompt
    python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"UserPromptSubmit","transcript_path":sys.argv[1],"prompt":sys.argv[2]}))' "$1" "$2"
}
skill_payload() { # transcript skill
    python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","transcript_path":sys.argv[1],"tool_name":"Skill","tool_input":{"skill":sys.argv[2],"args":"x"}}))' "$1" "$2"
}

# run <desc> <expect: silent|warn|context> <payload> [env-assignments…]
run() {
    local desc="$1" want="$2" payload="$3"; shift 3
    local out rc=0
    out="$(env "$@" bash "$HOOK" <<<"$payload" 2>/dev/null)" || rc=$?
    if [ "$rc" != 0 ]; then
        printf '  FAIL %s — exit %s (the hook is warn-only and must always exit 0)\n' "$desc" "$rc"; FAIL=1; return
    fi
    local got
    got="$(OUT="$out" python3 - <<'PY'
import json, os
out = os.environ["OUT"].strip()
if not out:
    print("silent"); raise SystemExit
try:
    d = json.loads(out)
except ValueError:
    print("invalid-json"); raise SystemExit
hso = d.get("hookSpecificOutput") or {}
ctx = hso.get("additionalContext", "")
if "permissionDecision" in hso or d.get("decision") == "block" or d.get("continue") is False:
    print("blocks"); raise SystemExit
if "ctx_tokens=" not in ctx:
    print("no-ctx-tokens"); raise SystemExit
print("warn" if d.get("systemMessage") else "context")
PY
)"
    if [ "$got" = "$want" ]; then
        printf '  ok   %s (%s)\n' "$desc" "$got"
    else
        printf '  FAIL %s — expected %s got %s\n' "$desc" "$want" "$got"; FAIL=1
    fi
}

transcript "$tmp/small.jsonl" 80000
transcript "$tmp/large.jsonl" 727344
transcript "$tmp/compacted.jsonl" 968800 \
    '{"type":"system","subtype":"compact_boundary","isSidechain":false,"compactMetadata":{"preTokens":968800,"postTokens":45142}}'
transcript "$tmp/sidechain.jsonl" 80000 \
    '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":1,"cache_read_input_tokens":900000,"cache_creation_input_tokens":0}}}'
transcript "$tmp/synthetic-tail.jsonl" 727344 \
    '{"type":"assistant","message":{"model":"<synthetic>","usage":{"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
printf '{"type":"user"\nnot json at all\n' > "$tmp/malformed.jsonl"

echo "UserPromptSubmit:"
run "plugin command, large context warns"          warn   "$(prompt_payload "$tmp/large.jsonl" '/magento2-tools:fix "orders miss company id"')"
run "plugin command, small context is silent"      silent "$(prompt_payload "$tmp/small.jsonl" '/magento2-tools:fix x')"
run "leading whitespace still matches"             warn   "$(prompt_payload "$tmp/large.jsonl" '  /magento2-tools:feature resume ./.docs/X')"
run "foreign slash command is silent"              silent "$(prompt_payload "$tmp/large.jsonl" '/code-review high')"
run "plain prompt mentioning the plugin is silent" silent "$(prompt_payload "$tmp/large.jsonl" 'why did magento2-tools:fix cost so much?')"
run "fresh compaction counts post-compact tokens"  silent "$(prompt_payload "$tmp/compacted.jsonl" '/magento2-tools:review Acme_X')"
run "sidechain usage is ignored"                   silent "$(prompt_payload "$tmp/sidechain.jsonl" '/magento2-tools:review Acme_X')"
run "zero-usage synthetic tail is skipped"         warn   "$(prompt_payload "$tmp/synthetic-tail.jsonl" '/magento2-tools:audit Acme_X')"
run "missing transcript fails open"                silent "$(prompt_payload "$tmp/nope.jsonl" '/magento2-tools:fix x')"
run "malformed transcript fails open"              silent "$(prompt_payload "$tmp/malformed.jsonl" '/magento2-tools:fix x')"
run "unparseable stdin fails open"                 silent 'this is not json'
run "unparseable stdin naming the plugin fails open" silent '{"prompt": "/magento2-tools:fix'
run "threshold override lowers the bar"            warn   "$(prompt_payload "$tmp/small.jsonl" '/magento2-tools:fix x')" MAGENTO2_TOOLS_CTX_WARN=50000
run "threshold 0 disables the hook"                silent "$(prompt_payload "$tmp/large.jsonl" '/magento2-tools:fix x')" MAGENTO2_TOOLS_CTX_WARN=0
run "non-numeric threshold falls back to 200k"     warn   "$(prompt_payload "$tmp/large.jsonl" '/magento2-tools:fix x')" MAGENTO2_TOOLS_CTX_WARN=lots

echo "PreToolUse (Skill):"
run "plugin skill, large context adds model context only" context "$(skill_payload "$tmp/large.jsonl" 'magento2-tools:review')"
run "plugin skill, small context is silent"         silent  "$(skill_payload "$tmp/small.jsonl" 'magento2-tools:review')"
run "foreign skill is silent"                       silent  "$(skill_payload "$tmp/large.jsonl" 'superpowers:brainstorming')"

# The user-facing warning must name the real numbers, the command, and the off switch.
msg="$(bash "$HOOK" <<<"$(prompt_payload "$tmp/large.jsonl" '/magento2-tools:fix x')" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])')"
for token in '~727k' '/magento2-tools:fix' '/clear' 'MAGENTO2_TOOLS_CTX_WARN'; do
    case "$msg" in
        *"$token"*) printf '  ok   warning names %s\n' "$token" ;;
        *) printf '  FAIL warning lacks %s: %s\n' "$token" "$msg"; FAIL=1 ;;
    esac
done

# A sub-1000 threshold must print as itself, never as "0k".
msg="$(MAGENTO2_TOOLS_CTX_WARN=500 bash "$HOOK" <<<"$(prompt_payload "$tmp/small.jsonl" '/magento2-tools:fix x')" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])')"
case "$msg" in
    *"threshold 500 tokens"*) printf '  ok   small threshold printed verbatim\n' ;;
    *) printf '  FAIL small threshold misprinted: %s\n' "$msg"; FAIL=1 ;;
esac

# Registration: both events wired in the plugin's hooks.json, through the plugin root.
python3 - <<'PY' || FAIL=1
import json, sys
d = json.load(open("hooks/hooks.json"))["hooks"]
def wired(event, matcher=None):
    for group in d.get(event, []):
        if matcher is not None and group.get("matcher") != matcher:
            continue
        for h in group.get("hooks", []):
            if "${CLAUDE_PLUGIN_ROOT}/hooks/context-budget.sh" in h.get("command", ""):
                return True
    return False
ok = True
for event, matcher in (("UserPromptSubmit", None), ("PreToolUse", "Skill")):
    if wired(event, matcher):
        print(f"  ok   hooks.json wires context-budget.sh on {event}" + (f" ({matcher})" if matcher else ""))
    else:
        print(f"  FAIL hooks.json does not wire context-budget.sh on {event}"); ok = False
sys.exit(0 if ok else 1)
PY

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "context-budget hook: warn-only, fail-open, registered"
exit 0
