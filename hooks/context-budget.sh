#!/usr/bin/env bash
# context-budget.sh — warn-only context-size guard for magento2-tools entry points.
#
# Every turn of a workflow re-reads the whole conversation, so the cost of a run scales with the
# context it STARTS in: a /magento2-tools:fix begun at ~727k tokens re-read that on each of its 95
# turns. This hook measures the conversation (last main-thread assistant usage in the transcript)
# and, above MAGENTO2_TOOLS_CTX_WARN tokens (default 200000; 0 disables):
#
#   UserPromptSubmit, prompt starts with /magento2-tools:<entry>
#       -> systemMessage for the user (recommend /clear + re-run) and additionalContext for the
#          model (ctx_tokens=..., read by context/references/execution-modes.md `auto` mode).
#   PreToolUse on Skill, skill magento2-tools:<name> (a model- or orchestrator-invoked skill)
#       -> additionalContext only, so a feature run chaining many sub-skills does not spam the user.
#
# It NEVER blocks: every path exits 0. It fails OPEN — silent — on any uncertainty: missing
# python3, unparseable input, no/unreadable transcript, an unrecognised transcript format (the
# JSONL layout is internal to Claude Code, not a documented contract), or a compaction newer than
# the last usage record (then the post-compaction size is used).
set -uo pipefail

input="$(cat)"

# Fast path: this runs on every prompt. Without the plugin namespace there is nothing to do,
# and python3 is never started.
case "$input" in
    *magento2-tools:*) ;;
    *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

HOOK_INPUT="$input" python3 - <<'PY' 2>/dev/null || true
import json, os, re, sys

DEFAULT_THRESHOLD = 200000
TAIL_BYTES = 4 * 1024 * 1024  # usage records sit at the end; never parse a whole 50 MB transcript


def threshold():
    raw = os.environ.get("MAGENTO2_TOOLS_CTX_WARN", "").strip()
    if not raw:
        return DEFAULT_THRESHOLD
    try:
        return int(raw)
    except ValueError:
        return DEFAULT_THRESHOLD


def context_tokens(path):
    """Context size of the main thread at its latest turn, or None when unknown."""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            fh.seek(max(0, size - TAIL_BYTES))
            data = fh.read()
    except (OSError, TypeError):
        return None
    lines = data.split(b"\n")
    if size > TAIL_BYTES:
        lines = lines[1:]  # the first line of a mid-file chunk is partial
    for raw in reversed(lines):
        if b'"assistant"' not in raw and b"compact_boundary" not in raw:
            continue
        try:
            rec = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(rec, dict) or rec.get("isSidechain"):
            continue
        if rec.get("type") == "system" and rec.get("subtype") == "compact_boundary":
            post = (rec.get("compactMetadata") or {}).get("postTokens")
            return post if isinstance(post, int) else 0
        if rec.get("type") != "assistant":
            continue
        msg = rec.get("message")
        usage = msg.get("usage") if isinstance(msg, dict) else None
        if not isinstance(usage, dict):
            continue
        total = sum(
            v for v in (usage.get(k) for k in (
                "input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
            if isinstance(v, int)
        )
        if total > 0:  # zero-usage (synthetic / interrupted) records say nothing; keep looking
            return total
    return None


try:
    payload = json.loads(os.environ.get("HOOK_INPUT", ""))
except ValueError:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)

event = payload.get("hook_event_name")
entry = None
if event == "UserPromptSubmit":
    m = re.match(r"\s*/magento2-tools:([\w-]+)", payload.get("prompt") or "")
    entry = m.group(1) if m else None
elif event == "PreToolUse" and payload.get("tool_name") == "Skill":
    tool_input = payload.get("tool_input")
    skill = tool_input.get("skill") if isinstance(tool_input, dict) else None
    if isinstance(skill, str) and skill.startswith("magento2-tools:"):
        entry = skill.split(":", 1)[1]
if not entry:
    sys.exit(0)

limit = threshold()
if limit <= 0:
    sys.exit(0)
ctx = context_tokens(payload.get("transcript_path"))
if ctx is None or ctx <= limit:
    sys.exit(0)

k = f"~{round(ctx / 1000)}k"
model_note = (
    f"magento2-tools context-budget: ctx_tokens={ctx} threshold={limit} status=above "
    f"(entry magento2-tools:{entry}). Per context/references/execution-modes.md, execution mode "
    f"`auto` resolves to `agents` for this run."
)
if event == "UserPromptSubmit":
    out = {
        "systemMessage": (
            f"magento2-tools: this conversation already holds {k} tokens of context, and every turn "
            f"of /magento2-tools:{entry} re-reads all of it. For a much cheaper run: /clear, then "
            f"re-run the same command. (Warning threshold {round(limit / 1000)}k; set "
            f"MAGENTO2_TOOLS_CTX_WARN to change it, 0 to disable.)"
        ),
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": model_note + " The user has already been shown a /clear recommendation.",
        },
    }
else:
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": model_note + (
                f" At the next natural stopping point (a phase boundary or an approval gate), tell "
                f"the user once that the conversation holds {k} tokens and recommend /clear, then "
                f"resuming from the run's on-disk artifacts."
            ),
        },
    }
print(json.dumps(out))
PY
exit 0
