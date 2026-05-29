#!/usr/bin/env bash
# snapshot.sh — pre-deploy snapshot of generated/, var/, optionally vendor/.
#
# Usage:
#   ./snapshot.sh <output-dir> [--include-vendor]
#
# Produces:
#   <output-dir>/snapshot-{YYYY-MM-DD-HHMMSS}.tar.gz
#
# Excludes:
#   var/cache/*  var/page_cache/*  var/log/*  pub/static/*  pub/media/*  node_modules/*
#
# These exclusions keep the snapshot small enough to be useful without bloating to GB.

set -euo pipefail

OUTPUT_DIR="${1:?usage: snapshot.sh <output-dir> [--include-vendor]}"
INCLUDE_VENDOR=0
if [ "${2:-}" = "--include-vendor" ]; then
    INCLUDE_VENDOR=1
fi

mkdir -p "$OUTPUT_DIR"
TS="$(date -u +%Y-%m-%d-%H%M%S)"
OUT="${OUTPUT_DIR}/snapshot-${TS}.tar.gz"

# Build target list with existence checks
declare -a TO_TAR
for t in generated var/composer_home var/.maintenance.flag; do
    [ -e "$t" ] && TO_TAR+=("$t")
done

# var/ minus cache/log directories
if [ -d var ]; then
    TO_TAR+=(--exclude='var/cache/*' --exclude='var/page_cache/*' --exclude='var/log/*' --exclude='var/session/*' --exclude='var/tmp/*' var)
fi

if [ "$INCLUDE_VENDOR" = "1" ] && [ -d vendor ]; then
    TO_TAR+=(--exclude='vendor/*/Test*' vendor)
fi

if [ "${#TO_TAR[@]}" = "0" ]; then
    echo "snapshot: nothing to snapshot (no generated/, var/, vendor/ directories found)" >&2
    exit 1
fi

tar -czf "$OUT" "${TO_TAR[@]}" 2>/dev/null

size="$(du -h "$OUT" | awk '{print $1}')"
echo "snapshot: wrote $OUT ($size)" >&2
echo "$OUT"
