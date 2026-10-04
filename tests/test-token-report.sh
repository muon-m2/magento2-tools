#!/usr/bin/env bash
# test-token-report.sh — scripts/token-report.py on a synthetic session: unique-message usage
# counting (streamed duplicates once), skill bucketing, Bash output classing, subagent typing via
# .meta.json, the weighted main/subagent split, and the directory form picking the newest session.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not available"; exit 77; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 - "$tmp" <<'PY'
import json, os, sys
root = sys.argv[1]
sess = os.path.join(root, "sess.jsonl")
def asst(mid, ctx, out, content=None, model="claude-opus-5-5", ts="2026-10-01T10:00:00Z"):
    return {"type": "assistant", "timestamp": ts, "message": {"id": mid, "model": model,
            "content": content or [], "usage": {"input_tokens": 0, "cache_read_input_tokens": ctx,
            "cache_creation_input_tokens": 0, "output_tokens": out}}}
rows = [
    asst("m1", 100000, 10),
    asst("m2", 300000, 20, [{"type": "tool_use", "id": "s1", "name": "Skill",
                              "input": {"skill": "magento2-tools:fix"}}]),
    # streamed duplicate of m2 carrying the next content block: usage must count once
    asst("m2", 300000, 20, [{"type": "tool_use", "id": "b1", "name": "Bash",
                              "input": {"command": "docker compose exec -T php vendor/bin/phpunit -c x"}}]),
    {"type": "user", "timestamp": "2026-10-01T10:00:01Z", "message": {"content": [
        {"type": "tool_result", "tool_use_id": "b1", "content": "x" * 4000}]}},
    {"type": "system", "subtype": "compact_boundary", "timestamp": "2026-10-01T10:00:02Z"},
    asst("m3", 500000, 30),
    asst("m4", 0, 0, model="<synthetic>"),
]
with open(sess, "w") as f:
    for r in rows: f.write(json.dumps(r) + "\n")
sub = os.path.join(root, "sess", "subagents"); os.makedirs(sub)
with open(os.path.join(sub, "agent-a1.jsonl"), "w") as f:
    f.write(json.dumps(asst("s1", 50000, 10, model="claude-sonnet-5-5")) + "\n")
with open(os.path.join(sub, "agent-a1.meta.json"), "w") as f:
    json.dump({"agentType": "magento2-tools:reviewer"}, f)
PY

out="$(python3 scripts/token-report.py "$tmp/sess.jsonl" --json)" || { echo "FAIL: token-report exited non-zero"; exit 1; }

OUT="$out" python3 - <<'PY'
import json, os, sys
r = json.loads(os.environ["OUT"])
m = r["main"]
checks = [
    ("3 unique main turns (duplicate + synthetic skipped)", m["turns"] == 3),
    ("summed context 900k", m["ctx_sum"] == 900000),
    ("max context 500k", m["ctx_max"] == 500000),
    ("2 turns above the 200k default threshold", m["turns_above_threshold"] == 2),
    ("1 compaction", m["compactions"] == 1),
    ("fix bucket holds the turns after the Skill call",
     any(b["skill"] == "magento2-tools:fix" and b["turns"] == 2 for b in m["skill_buckets"])),
    ("phpunit output classed and sized",
     any(b["class"] == "phpunit" and b["calls"] == 1 and b["chars"] == 4000 for b in m["bash_output"])),
    ("subagent typed from meta.json",
     [a["type"] for a in r["subagents"]] == ["magento2-tools:reviewer"]),
    ("no Opus among subagents", r["opus_share_of_subagents"] == 0.0),
    ("main share between 0 and 1", 0 < r["main_share"] < 1),
]
bad = [d for d, ok in checks if not ok]
for d, ok in checks:
    print(("  ok   " if ok else "  FAIL ") + d)
sys.exit(1 if bad else 0)
PY
rc=$?

# Directory form: newest session in the folder; text mode prints the headline rows.
txt="$(python3 scripts/token-report.py "$tmp")" || rc=1
for token in 'Main thread: 3 turns' 'magento2-tools:reviewer' 'magento2-tools:fix' 'phpunit'; do
    case "$txt" in
        *"$token"*) echo "  ok   text report shows '$token'" ;;
        *) echo "  FAIL text report lacks '$token'"; rc=1 ;;
    esac
done

[ "$rc" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "token-report: counts, buckets, classes and subagent split verified"
exit 0
