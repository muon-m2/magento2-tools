#!/usr/bin/env bash
# verify-created.sh must syntax-check EVERY PHP file when PHP runs inside Docker.
#
# The PHP lint loop is fed by `done < <(find … -print0)`, and each iteration runs `$PHP_CMD -l`.
# When a php compose service is running, PHP_CMD is `docker compose exec -T -u magento php php`,
# and `docker compose exec -T` reads stdin — so the first `php -l` drained the rest of the file
# list, the loop ended after one file, and the check printed "All PHP files pass syntax check".
# Same defect class as deploy's execute-plan.sh (tests/test-deploy-execute-plan-stdin.sh).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="$PWD/skills/module-create/scripts/verify-created.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A `docker` stand-in: a php compose service is running, and `compose exec -T` behaves like the real
# one — it drains stdin — before answering as `php -l` would.
BIN="$WORK/bin"; mkdir -p "$BIN"
cat > "$BIN/docker" <<'SH'
#!/usr/bin/env bash
case "$*" in
    "compose ps php") echo "acme-php   php   running" ;;
    "compose exec -T -u magento php php -v") cat >/dev/null; echo "PHP 8.5.0 (cli)" ;;
    "compose exec -T -u magento php php -l "*)
        cat >/dev/null
        printf '%s\n' "${!#}" >> "$LINT_LOG"
        echo "No syntax errors detected in ${!#}" ;;
    *) cat >/dev/null; exit 1 ;;
esac
SH
chmod +x "$BIN/docker"

MOD="$WORK/app/code/Acme/Probe"
mkdir -p "$MOD/Model" "$MOD/etc"
for f in registration.php Model/Alpha.php Model/Beta.php Model/Gamma.php; do
    printf '<?php\ndeclare(strict_types=1);\n' > "$MOD/$f"
done

LINT_LOG="$WORK/lint.log"; : > "$LINT_LOG"
PATH="$BIN:$PATH" LINT_LOG="$LINT_LOG" bash "$SCRIPT" "$MOD" >"$WORK/out.txt" 2>&1 </dev/null

expected="$(find "$MOD" -type f -name '*.php' | wc -l | tr -d ' ')"
linted="$(wc -l < "$LINT_LOG" | tr -d ' ')"

if [ "$linted" = "$expected" ]; then
    echo "PASS: verify-created syntax-checks all $expected PHP files through a stdin-reading runner"
    exit 0
fi
echo "FAIL: $linted of $expected PHP files were syntax-checked through the Docker runner"
echo "--- linted ---"; cat "$LINT_LOG"
echo "--- output ---"; grep -i 'syntax' "$WORK/out.txt"
exit 1
