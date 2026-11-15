#!/usr/bin/env bash
# M6 / L3：同一份语料 × 多后端 × 多入口，逐字节比对，必须零差异。
#
# 比对对象：
#   cli/js          moon run --target js        cli
#   cli/wasm        moon run --target wasm      cli
#   cli/wasm-gc     moon run --target wasm-gc   cli
#   npm/esm         js 产物在 Node 里直接调用 goldenBundle()
#   entry/wasm      wasm 包自身的 main 入口
#   cli/native      （仅当宿主有 C 编译器时）
#   golden          testdata/expected/bundle.txt
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT=".consistency"
rm -rf "$OUT"
mkdir -p "$OUT"
FILES=()

for target in js wasm wasm-gc; do
  echo "== run cli on $target =="
  "$MOON_BIN" run --target "$target" cli 2>/dev/null > "$OUT/cli-$target.txt"
  FILES+=("$OUT/cli-$target.txt")
done

echo "== run npm ESM artifact on Node =="
"$MOON_BIN" build --target js --quiet js >/dev/null
node --input-type=module -e \
  "import('./_build/js/debug/build/js/js.js').then(m => process.stdout.write(m.goldenBundle()))" \
  > "$OUT/npm-esm.txt"
FILES+=("$OUT/npm-esm.txt")

echo "== run wasm package entry =="
"$MOON_BIN" run --target wasm wasm 2>/dev/null > "$OUT/entry-wasm.txt"
FILES+=("$OUT/entry-wasm.txt")

if command -v cl.exe >/dev/null 2>&1 || command -v clang-cl.exe >/dev/null 2>&1 ||
   command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1; then
  echo "== run cli on native =="
  "$MOON_BIN" run --target native cli 2>/dev/null > "$OUT/cli-native.txt"
  FILES+=("$OUT/cli-native.txt")
else
  echo "== native SKIPPED (no C compiler); moon check --target native 已覆盖编译期验证 =="
  "$MOON_BIN" check --target native >/dev/null
fi

GOLDEN="testdata/expected/bundle.txt"
if [[ -f "$GOLDEN" ]]; then
  FILES+=("$GOLDEN")
fi

BASE="${FILES[0]}"
STATUS=0
for f in "${FILES[@]:1}"; do
  if cmp -s "$BASE" "$f"; then
    echo "OK   $(basename "$f")  ($(wc -c < "$f" | tr -d ' ') bytes)"
  else
    echo "FAIL $(basename "$f") differs from $(basename "$BASE")" >&2
    diff -u "$BASE" "$f" | head -40 >&2 || true
    STATUS=1
  fi
done

if [[ $STATUS -ne 0 ]]; then
  echo "CONSISTENCY FAILED" >&2
  exit 1
fi
echo "CONSISTENCY OK: ${#FILES[@]} outputs are byte-identical ($(wc -c < "$BASE" | tr -d ' ') bytes each)"
