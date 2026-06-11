# Exception Log Baseline (S1 + S8)

The smoke battery requires `var/log/exception.log` to gain **zero new lines** during a successful
run (acceptance criterion #9). This is enforced by byte-offset snapshot (S1) and tail-since-offset
diff (S8).

---

## Why byte-offset, not line-count

A Magento site under any kind of background load (cron, indexer, queue consumer, deploy hooks)
can write to `exception.log` between S1 and S8 from sources unrelated to the feature being
smoke-tested. The check is still useful — but only if it can distinguish the new feature's lines
from background noise.

Byte-offset wins over line-count for three reasons:

1. **Rotation detection.** If the file rotates between S1 and S8, the byte size drops and the
   `sha256_of_last_4096` no longer matches; we treat the entire post-rotation file as new and
   report appropriately.
2. **Concurrent writes.** Line-count diffs lose lines written *between* the read and the count.
   Byte-offset locks in a position; everything after it is "new".
3. **Allowlist precision.** The diff is delivered as raw bytes and can be regex-matched in full,
   including multi-line stack traces that line-count would split.

---

## Baseline file format

```
file=src/var/log/exception.log
size_bytes=12834
sha256_of_last_4096=ef9c4d2b...
captured_at=2026-05-28T10:14:22Z
```

The `sha256_of_last_4096` hashes the last 4 KiB of the file at baseline time (or the whole file
if shorter). It is the rotation-detection hash: if at diff time the file's first 4 KiB does not
contain that hash region, the file rotated.

---

## Diff algorithm (S8)

```text
1. Read baseline.txt.
2. Stat the live file.
3. If live size >= baseline size:
   3a. Read live bytes [baseline_size .. EOF] — that is the diff.
   3b. Optionally verify the byte just before baseline_size still matches what we expect
       (or that the 4KiB sha around baseline_size still matches) to detect mid-flight truncation.
4. If live size <  baseline size:
   4a. The file rotated (or was truncated). Treat live bytes [0 .. EOF] as the diff.
   4b. Also check for the rotated file under `var/log/exception.log.1` etc. and prepend any
       lines after baseline_size in that file to the diff.
5. Save the diff to smoke/raw/S8/exception-diff.log.
6. If the diff contains no new or unresolved exception groups → S8 passes. (An empty diff is
   the simplest such case; a diff that holds only groups already marked `resolved` in
   findings.md also passes — see "How fixes interact with the baseline" below.)
7. Otherwise → each new "exception group" (a logical group of consecutive lines that share a
   timestamp and trace) that is not already a resolved finding becomes one finding.
```

An "exception group" is detected by Magento's own log format: lines starting with
`[YYYY-MM-DD HH:MM:SS]` start a new group; subsequent indented or non-timestamped lines belong
to the same group.

---

## Allowlist

A site may have legitimate noise it knows is unrelated to the smoke run. The user opts in via
`CLAUDE.md`:

```
Smoke exception ignore:
  - ^Cron \w+ heartbeat OK$
  - ^Indexer reindex completed for \w+$
```

Each line under `Smoke exception ignore:` is a PCRE pattern. A diff group whose first line matches
**any** pattern is demoted from Critical to Medium and recorded as "allowlisted" in the run report.

The allowlist is intentionally not stored in the skill — it is per-site and per-deployment. The
skill reads CLAUDE.md once at S1 and applies the patterns at S8.

---

## What does NOT count as a finding

- `var/log/system.log` entries — only `exception.log` is the strict gate. System log entries
  that look suspicious become Medium findings via the broader S9 triage.
- Lines that pre-date the baseline (i.e. existed before S1) — those were already there and are
  not the smoke run's responsibility.

---

## How fixes interact with the baseline

The baseline is captured **once per skill run**, not once per Phase 6 iteration — so the S8
diff (live log minus baseline) ACCUMULATES every exception logged since the run started, and a
group never leaves the diff just because it was fixed.

Because of that, the S8 pass criterion is **"no new or unresolved exception groups"**, NOT
"the diff is empty". An empty-diff criterion is unsatisfiable once any exception has ever been
logged in the run: iteration 1's exception stays in the diff at iterations 2–5 even after it is
fixed, which would force the loop to the 5-iteration cap every time (FI-1). Instead:

- Every exception **group** in the S8 diff is tracked in `findings.md` with a status.
- A group whose fix landed in an earlier iteration is marked `resolved` — its lingering bytes
  in the diff are EXPECTED and do **not** fail S8.
- S8 fails 6B only when the diff contains a group that is **new** (first seen this iteration)
  or still **unresolved**.
- The "5 iterations" cap still bounds pathological loops; `findings.md` carries the
  cross-iteration memory so resolved groups are not re-counted.

If a fix legitimately needs to rotate the log (rare — typically only when iteration 1's
exception was so large it interferes with diffing), the fix delegate writes a one-line note to
`smoke/baseline.txt` and re-captures. This is logged in the iteration report and counts as a
finding (Medium) in its own right.

---

## File locations

The Magento root may be `src/` or the working directory. The baseline file resolver uses, in order:

1. `src/var/log/exception.log` (if `src/app/etc/env.php` exists).
2. `var/log/exception.log` (if `app/etc/env.php` exists at project root).
3. The first `var/log/exception.log` found via `find` capped at depth 3.

If none is found, S1 reports "no log file at baseline" — which is itself a finding (Medium):
either the path is wrong or the site has never logged any exception, which is improbable enough
to be worth flagging.
