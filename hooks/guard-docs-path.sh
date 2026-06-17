#!/usr/bin/env bash
# guard-docs-path.sh — PreToolUse guard enforcing the magento2-context .docs/ rule.
#
# Blocks Write/Edit of a .docs/ artifact anywhere other than {CLAUDE_PROJECT_DIR}/.docs/
# in a detected Magento project. Fails OPEN (exit 0) on any uncertainty: missing python3,
# missing CLAUDE_PROJECT_DIR, unparseable input, non-Write/Edit tool, no file_path, a
# non-Magento repo, or a path outside the project root. A confirmed misplaced .docs/ write
# is denied with exit code 2 (the documented PreToolUse block). There is no escape hatch by
# design, so every uncertain branch allows.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./docs-path-matcher.sh
. "$HERE/docs-path-matcher.sh"

# Fail open if python3 is unavailable (robustness fallback, not a user escape hatch).
command -v python3 >/dev/null 2>&1 || exit 0

# Project root from the environment; fail open if absent. Strip any trailing slash.
project_root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$project_root" ] || exit 0
project_root="${project_root%/}"

input="$(cat)"

# Parse tool_name + resolve an absolute, normalized file_path. NUL-delimited so paths with
# spaces survive; python3 prints nothing on bad JSON -> fields stay empty -> allow.
tool_name=""; file_path=""
{
    IFS= read -r -d '' tool_name || true
    IFS= read -r -d '' file_path || true
} < <(
    CLAUDE_PROJECT_DIR="$project_root" python3 - "$input" <<'PY' 2>/dev/null || true
import json, os, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
tn = d.get("tool_name") or ""
ti = d.get("tool_input")
fp = ti.get("file_path") if isinstance(ti, dict) else ""
fp = fp or ""
cwd = d.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR", "")
if fp and not os.path.isabs(fp):
    fp = os.path.join(cwd, fp)
fp = os.path.normpath(fp) if fp else ""
sys.stdout.write(tn + "\0" + fp + "\0")
PY
)

# Only governs file-writing tools.
case "$tool_name" in
    Write|Edit) ;;
    *) exit 0 ;;
esac
[ -n "$file_path" ] || exit 0

# Scope gate: is this a Magento project? (cheap filesystem markers, both repo layouts)
is_magento=no
if [ -e "$project_root/bin/magento" ] || [ -d "$project_root/app/etc" ] \
   || [ -e "$project_root/src/bin/magento" ] || [ -d "$project_root/src/app/etc" ] \
   || { [ -f "$project_root/composer.json" ] && grep -q 'magento/' "$project_root/composer.json"; }; then
    is_magento=yes
fi

if [ "$(docs_path_decide "$project_root" "$file_path" "$is_magento")" = "deny" ]; then
    rel="${file_path#"$project_root"/}"
    {
        echo "magento2-tools: blocked writing a .docs/ artifact at '$rel'."
        echo "All .docs/ artifacts must live at the project root: $project_root/.docs/"
        echo "(magento2-context Core Rules: never write .docs/ under the Magento tree)."
    } >&2
    exit 2
fi
exit 0
