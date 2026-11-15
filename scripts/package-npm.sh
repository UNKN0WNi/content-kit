#!/usr/bin/env bash
# M8：产出 npm 包目录（ESM + .d.ts + 冒烟测试）。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

"$MOON_BIN" build --target js --quiet js >/dev/null
mkdir -p js/dist
cp _build/js/debug/build/js/js.js js/dist/contentkit.js
cp js/index.d.ts js/dist/index.d.ts
echo "npm artifact: js/dist/contentkit.js ($(wc -c < js/dist/contentkit.js | tr -d ' ') bytes)"

if command -v node >/dev/null 2>&1; then
  (cd js && node ./test/smoke.mjs)
fi
