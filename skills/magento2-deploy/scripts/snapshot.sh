#!/usr/bin/env bash
# snapshot.sh — pre-deploy snapshot of generated/, var/, optionally vendor/ and the DB.
#
# Usage:
#   ./snapshot.sh <output-dir> [--include-vendor] [--include-db]
#
# Produces:
#   <output-dir>/snapshot-{YYYY-MM-DD-HHMMSS}.tar.gz      (filesystem)
#   <output-dir>/db-{YYYY-MM-DD-HHMMSS}.sql.gz            (only with --include-db)
#
# Filesystem excludes:
#   var/cache/*  var/page_cache/*  var/log/*  var/session/*  var/tmp/*  (kept small)
#
# IMPORTANT — what this snapshot can and cannot roll back:
#   The filesystem snapshot covers generated/ and var/ ONLY. It does NOT capture the
#   database. A "git revert + re-run setup:upgrade" rollback is therefore LOSSY:
#     * applied data patches are recorded in the `patch_list` table and will NOT be
#       re-applied or undone by setup:upgrade;
#     * declarative-schema column/table drops are destructive and cannot be recovered
#       from code.
#   To be able to roll the database back, take a DB dump too (--include-db) and restore it
#   with the recipe printed below before re-running setup:upgrade.

set -euo pipefail

OUTPUT_DIR="${1:?usage: snapshot.sh <output-dir> [--include-vendor] [--include-db]}"
shift || true

INCLUDE_VENDOR=0
INCLUDE_DB=0
for arg in "$@"; do
    case "$arg" in
        --include-vendor) INCLUDE_VENDOR=1 ;;
        --include-db)     INCLUDE_DB=1 ;;
        *) echo "snapshot: unknown argument '$arg'" >&2; exit 2 ;;
    esac
done

mkdir -p "$OUTPUT_DIR"
TS="$(date -u +%Y-%m-%d-%H%M%S)"
OUT="${OUTPUT_DIR}/snapshot-${TS}.tar.gz"

# Build the tar argv with ALL --exclude options first, then the paths. bsdtar (macOS) is
# order-sensitive — excludes that appear after their paths are ignored; GNU tar accepts
# either order, so leading excludes are the portable choice.
declare -a TAR_EXCLUDES=()
declare -a TAR_PATHS=()

for t in generated var/composer_home var/.maintenance.flag; do
    [ -e "$t" ] && TAR_PATHS+=("$t")
done

if [ -d var ]; then
    TAR_EXCLUDES+=(--exclude='var/cache/*' --exclude='var/page_cache/*' \
        --exclude='var/log/*' --exclude='var/session/*' --exclude='var/tmp/*')
    TAR_PATHS+=(var)
fi

if [ "$INCLUDE_VENDOR" = "1" ] && [ -d vendor ]; then
    TAR_EXCLUDES+=(--exclude='vendor/*/Test*')
    TAR_PATHS+=(vendor)
fi

if [ "${#TAR_PATHS[@]}" = "0" ]; then
    echo "snapshot: nothing to snapshot (no generated/, var/, vendor/ directories found)" >&2
    exit 1
fi

# Loud failure: the old `2>/dev/null` swallowed tar errors, which under `set -e` could leave
# a truncated/absent archive while the script reported success.
if ! tar -czf "$OUT" "${TAR_EXCLUDES[@]}" "${TAR_PATHS[@]}"; then
    echo "snapshot: tar failed writing $OUT" >&2
    exit 1
fi

size="$(du -h "$OUT" | awk '{print $1}')"
echo "snapshot: wrote $OUT ($size)" >&2

# --- Optional database dump --------------------------------------------------
if [ "$INCLUDE_DB" = "1" ]; then
    ENV_PHP=""
    for p in app/etc/env.php src/app/etc/env.php; do
        [ -f "$p" ] && ENV_PHP="$p" && break
    done
    if [ -z "$ENV_PHP" ]; then
        echo "snapshot: --include-db requested but app/etc/env.php not found" >&2
        exit 1
    fi
    if ! command -v php >/dev/null 2>&1; then
        echo "snapshot: --include-db needs php to read DB credentials from $ENV_PHP" >&2
        exit 1
    fi

    # Read the default connection. Tab-separated so passwords with spaces survive.
    creds="$(php -r '
        $e = include $argv[1];
        $c = $e["db"]["connection"]["default"] ?? [];
        echo implode("\t", [
            $c["host"] ?? "localhost",
            $c["dbname"] ?? "",
            $c["username"] ?? "",
            $c["password"] ?? "",
        ]);
    ' "$ENV_PHP")"
    IFS=$'\t' read -r DB_HOST DB_NAME DB_USER DB_PASS <<< "$creds"

    DB_PORT=3306
    case "$DB_HOST" in
        *:*) DB_PORT="${DB_HOST##*:}"; DB_HOST="${DB_HOST%%:*}" ;;
    esac

    if [ -z "$DB_NAME" ]; then
        echo "snapshot: could not read dbname from $ENV_PHP" >&2
        exit 1
    fi
    if ! command -v mysqldump >/dev/null 2>&1; then
        echo "snapshot: mysqldump not on PATH. For a Docker DB, run mysqldump INSIDE the db" >&2
        echo "          container, or take the DB backup manually before deploying:" >&2
        echo "          docker compose exec db mysqldump -u<user> -p <db> | gzip > db.sql.gz" >&2
        exit 1
    fi

    DB_OUT="${OUTPUT_DIR}/db-${TS}.sql.gz"
    # --single-transaction: consistent InnoDB dump without locking.
    # --no-tablespaces: avoids the PROCESS privilege requirement on MySQL 8.
    if ! MYSQL_PWD="$DB_PASS" mysqldump --single-transaction --quick --no-tablespaces \
            -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" 2>/tmp/mysqldump.err \
            | gzip > "$DB_OUT"; then
        echo "snapshot: mysqldump failed: $(head -c 300 /tmp/mysqldump.err | tr -d '\n')" >&2
        echo "          (Docker note: the DB host '${DB_HOST}' is often only reachable from" >&2
        echo "           inside the compose network — dump from the db container instead.)" >&2
        rm -f "$DB_OUT"
        exit 1
    fi
    db_size="$(du -h "$DB_OUT" | awk '{print $1}')"
    echo "snapshot: wrote DB dump $DB_OUT ($db_size)" >&2
    echo "snapshot: restore with:  gunzip < ${DB_OUT} | MYSQL_PWD=<pass> mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_NAME}" >&2
fi

echo "$OUT"
