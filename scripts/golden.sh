#!/usr/bin/env bash
# Golden Vector 快照回归。默认比对；传 --update 重新生成期望输出。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

GOLDEN="testdata/expected/bundle.txt"
mkdir -p "$(dirname "$GOLDEN")"
TMP=".consistency/golden-current.txt"
mkdir -p "$(dirname "$TMP")"
"$MOON_BIN" run --target js cli 2>/dev/null > "$TMP"

if [[ "${1:-}" == "--update" ]]; then
  cp "$TMP" "$GOLDEN"
  echo "golden updated: $GOLDEN ($(wc -c < "$GOLDEN" | tr -d ' ') bytes)"
elif [[ ! -f "$GOLDEN" ]]; then
  echo "golden missing, run: bash scripts/golden.sh --update" >&2
  exit 1
elif cmp -s "$TMP" "$GOLDEN"; then
  echo "golden OK: $GOLDEN ($(wc -c < "$GOLDEN" | tr -d ' ') bytes)"
else
  echo "golden MISMATCH" >&2
  diff -u "$GOLDEN" "$TMP" | head -60 >&2 || true
  exit 1
fi
