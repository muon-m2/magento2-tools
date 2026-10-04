#!/usr/bin/env python3
"""token-report.py — where a Claude Code session's tokens went (developer tool, not a skill).

Reads a session transcript (JSONL) plus its subagent transcripts and prints, compactly:
  * main thread: turns, summed context, context p50/p90/max, turns above a threshold, compactions;
  * weighted cost split main vs subagents (list-price ratios: input 1, cache read 0.1,
    cache write 1.25, output 5 — a relative unit, not dollars);
  * subagents by type: count, turns, summed/peak context, model mix, cost share;
  * main-thread context bucketed by the last magento2-tools (or other) skill invoked;
  * main-thread Bash output volume by command class.

Usage:
  token-report.py <session.jsonl | transcripts-dir> [--since ISO8601] [--threshold N] [--json]

A directory picks its most recently modified top-level *.jsonl. Context per turn is
input + cache_read + cache_write of each unique assistant message (streamed duplicates share an
id and are counted once). The transcript format is internal to Claude Code: unknown records are
skipped, never fatal.
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

WEIGHTS = {"input": 1.0, "cache_read": 0.1, "cache_write": 1.25, "output": 5.0}


def read_jsonl(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if isinstance(rec, dict):
                yield rec


def usage_of(rec):
    msg = rec.get("message")
    u = msg.get("usage") if isinstance(msg, dict) else None
    if not isinstance(u, dict):
        return None
    g = lambda k: u.get(k) if isinstance(u.get(k), int) else 0
    return {"input": g("input_tokens"), "cache_read": g("cache_read_input_tokens"),
            "cache_write": g("cache_creation_input_tokens"), "output": g("output_tokens")}


def ctx_of(u):
    return u["input"] + u["cache_read"] + u["cache_write"]


def weighted(u):
    return sum(WEIGHTS[k] * u[k] for k in WEIGHTS)


def classify_bash(cmd):
    if "magento2-tools" in cmd:
        m = re.search(r"/skills/([\w-]+)/scripts/([\w.-]+)", cmd)
        if m:
            return f"plugin script: {m.group(1)}/{m.group(2)}"
        if re.search(r"/skills/[\w-]+", cmd):
            return "reading plugin skill files"
    rules = [
        ("phpunit", r"phpunit"),
        ("static analysis", r"phpcs|phpstan|phpmd|php-cs-fixer|rector"),
        ("bin/magento", r"bin/magento"),
        ("node / browser smoke", r"\bnode\b|playwright|\.mjs\b"),
        ("curl", r"\bcurl\b"),
        ("database", r"\bmysql\b|\bmariadb\b"),
        ("git", r"^\s*(cd [^;&]+(&&|;)\s*)?git\b"),
        ("file write (heredoc/tee)", r"cat\s*>|<<\s*['\"]?\w+|\btee\b"),
        ("file read/search", r"\b(cat|sed|head|tail|grep|rg|find|ls|wc|awk)\b"),
    ]
    for name, pat in rules:
        if re.search(pat, cmd):
            return name
    return "other"


def tool_result_chars(item):
    c = item.get("content")
    if isinstance(c, str):
        return len(c)
    if isinstance(c, list):
        return sum(len(x.get("text", "")) for x in c if isinstance(x, dict))
    return 0


def analyse_main(path, since, threshold):
    seen, turns = set(), []
    buckets = collections.OrderedDict()
    current = "(before any skill)"
    bash_cmd, bash_out = {}, collections.defaultdict(lambda: [0, 0])
    compactions, first_ts, last_ts = 0, None, None
    for rec in read_jsonl(path):
        ts = rec.get("timestamp") or ""
        typ = rec.get("type")
        if rec.get("isSidechain"):
            continue
        if typ == "system" and rec.get("subtype") == "compact_boundary" and ts >= since:
            compactions += 1
        if typ == "assistant":
            content = (rec.get("message") or {}).get("content")
            for c in content if isinstance(content, list) else []:
                if not isinstance(c, dict) or c.get("type") != "tool_use":
                    continue
                inp = c.get("input") if isinstance(c.get("input"), dict) else {}
                if c.get("name") == "Skill" and inp.get("skill"):
                    current = inp["skill"]
                elif c.get("name") == "Bash":
                    bash_cmd[c.get("id")] = inp.get("command", "")
            mid = (rec.get("message") or {}).get("id")
            u = usage_of(rec)
            if u is None or mid in seen or ts < since:
                continue
            seen.add(mid)
            if ctx_of(u) == 0 and u["output"] == 0:
                continue  # synthetic / interrupted record
            turns.append(u)
            b = buckets.setdefault(current, [0, 0, 0])
            b[0] += 1
            b[1] += ctx_of(u)
            b[2] = max(b[2], ctx_of(u))
            first_ts = first_ts or ts
            last_ts = ts
        elif typ == "user" and ts >= since:
            content = (rec.get("message") or {}).get("content")
            for item in content if isinstance(content, list) else []:
                if isinstance(item, dict) and item.get("type") == "tool_result" \
                        and item.get("tool_use_id") in bash_cmd:
                    cls = classify_bash(bash_cmd[item["tool_use_id"]])
                    bash_out[cls][0] += 1
                    bash_out[cls][1] += tool_result_chars(item)
    ctxs = sorted(ctx_of(u) for u in turns)
    pct = lambda p: ctxs[min(len(ctxs) - 1, int(p * len(ctxs)))] if ctxs else 0
    return {
        "span": [first_ts, last_ts],
        "turns": len(turns),
        "ctx_sum": sum(ctxs),
        "ctx_p50": pct(0.5),
        "ctx_p90": pct(0.9),
        "ctx_max": ctxs[-1] if ctxs else 0,
        "turns_above_threshold": sum(1 for c in ctxs if c > threshold),
        "compactions": compactions,
        "weighted": sum(weighted(u) for u in turns),
        "skill_buckets": [{"skill": k, "turns": v[0], "ctx_sum": v[1], "ctx_max": v[2]}
                          for k, v in buckets.items()],
        "bash_output": sorted(({"class": k, "calls": v[0], "chars": v[1]}
                               for k, v in bash_out.items()), key=lambda r: -r["chars"]),
    }


def analyse_subagents(session_path, since):
    folder = session_path[:-len(".jsonl")] + "/subagents"
    agg = {}
    for p in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        agent_type = "?"
        meta = p[:-len(".jsonl")] + ".meta.json"
        try:
            with open(meta, encoding="utf-8") as fh:
                agent_type = json.load(fh).get("agentType") or "?"
        except (OSError, ValueError):
            pass
        seen, n, ctx_sum, ctx_max, w = set(), 0, 0, 0, 0.0
        models = collections.Counter()
        for rec in read_jsonl(p):
            if rec.get("type") != "assistant" or (rec.get("timestamp") or "") < since:
                continue
            mid = (rec.get("message") or {}).get("id")
            u = usage_of(rec)
            if u is None or mid in seen:
                continue
            seen.add(mid)
            n += 1
            ctx_sum += ctx_of(u)
            ctx_max = max(ctx_max, ctx_of(u))
            w += weighted(u)
            models[(rec.get("message") or {}).get("model") or "?"] += 1
        if not n:
            continue
        a = agg.setdefault(agent_type, {"type": agent_type, "count": 0, "turns": 0, "ctx_sum": 0,
                                        "ctx_max": 0, "weighted": 0.0, "models": collections.Counter(),
                                        "weighted_by_model": collections.Counter()})
        a["count"] += 1
        a["turns"] += n
        a["ctx_sum"] += ctx_sum
        a["ctx_max"] = max(a["ctx_max"], ctx_max)
        a["weighted"] += w
        a["models"].update(models)
        top_model = models.most_common(1)[0][0]
        a["weighted_by_model"][top_model] += w
    return sorted(agg.values(), key=lambda a: -a["weighted"])


def resolve_session(arg):
    if os.path.isdir(arg):
        cands = [p for p in glob.glob(os.path.join(arg, "*.jsonl"))]
        if not cands:
            sys.exit(f"token-report: no *.jsonl in {arg}")
        return max(cands, key=os.path.getmtime)
    if not os.path.isfile(arg):
        sys.exit(f"token-report: not found: {arg}")
    return arg


def human(n):
    for unit, div in (("B", 1e9), ("M", 1e6), ("k", 1e3)):
        if abs(n) >= div:
            return f"{n / div:.1f}{unit}"
    return f"{n:.0f}"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("session", help="session .jsonl, or a transcripts directory (newest session)")
    ap.add_argument("--since", default="", help="only count records at/after this ISO timestamp")
    ap.add_argument("--threshold", type=int, default=200000, help="context threshold (default 200000)")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--top", type=int, default=8, help="rows per table (default 8)")
    args = ap.parse_args()

    path = resolve_session(args.session)
    main_t = analyse_main(path, args.since, args.threshold)
    subs = analyse_subagents(path, args.since)
    sub_w = sum(a["weighted"] for a in subs)
    total_w = main_t["weighted"] + sub_w
    opus_w = sum(w for a in subs for m, w in a["weighted_by_model"].items() if "opus" in m)

    report = {
        "session": os.path.basename(path),
        "main": main_t,
        "subagents": [dict(a, models=dict(a["models"]), weighted_by_model=dict(a["weighted_by_model"]))
                      for a in subs],
        "weighted_total": total_w,
        "main_share": main_t["weighted"] / total_w if total_w else 0.0,
        "opus_share_of_subagents": opus_w / sub_w if sub_w else 0.0,
        "threshold": args.threshold,
    }
    if args.json:
        print(json.dumps(report, indent=2, default=str))
        return

    m = main_t
    print(f"Session {report['session']}  ({m['span'][0] or '?'} -> {m['span'][1] or '?'})")
    print(f"Main thread: {m['turns']} turns · Σctx {human(m['ctx_sum'])} · ctx p50 {human(m['ctx_p50'])} "
          f"p90 {human(m['ctx_p90'])} max {human(m['ctx_max'])} · {m['turns_above_threshold']} turns "
          f">{human(args.threshold)} · {m['compactions']} compactions")
    print(f"Weighted cost {human(total_w)} (in 1 / cache-read 0.1 / cache-write 1.25 / out 5): "
          f"main {100 * report['main_share']:.0f}%, subagents {100 - 100 * report['main_share']:.0f}%"
          + (f" · Opus share of subagents {100 * report['opus_share_of_subagents']:.0f}%" if subs else ""))
    if subs:
        print("\nSubagents (type · n · turns · Σctx · max ctx · share · models)")
        for a in subs[:args.top]:
            share = 100 * a["weighted"] / total_w if total_w else 0
            models = ", ".join(f"{k}×{v}" for k, v in a["models"].most_common(2))
            print(f"  {a['type'][:34]:34} {a['count']:3} {a['turns']:5} {human(a['ctx_sum']):>7} "
                  f"{human(a['ctx_max']):>7} {share:5.1f}%  {models}")
    print("\nMain thread by last-invoked skill (skill · turns · Σctx · max ctx)")
    for b in sorted(m["skill_buckets"], key=lambda b: -b["ctx_sum"])[:args.top]:
        print(f"  {b['skill'][:40]:40} {b['turns']:5} {human(b['ctx_sum']):>7} {human(b['ctx_max']):>7}")
    if m["bash_output"]:
        print("\nMain-thread Bash output (class · calls · ≈tokens)")
        for r in m["bash_output"][:args.top]:
            print(f"  {r['class'][:40]:40} {r['calls']:5} {human(r['chars'] / 4):>7}")


if __name__ == "__main__":
    main()
