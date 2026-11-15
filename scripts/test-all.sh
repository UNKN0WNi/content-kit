#!/usr/bin/env bash
# S8/CI：格式化检查 + 四后端类型检查 + 可运行后端的全量测试。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "== moon fmt --check =="
"$MOON_BIN" fmt --check

echo "== moon check --target all =="
"$MOON_BIN" check --target all

for target in js wasm wasm-gc; do
  echo "== moon test --target $target =="
  "$MOON_BIN" test --target "$target"
done

# native 测试需要 MSVC（Windows）/ gcc（Unix）链接器。
if command -v cl.exe >/dev/null 2>&1 || command -v clang-cl.exe >/dev/null 2>&1 ||
   command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1; then
  echo "== moon test --target native =="
  "$MOON_BIN" test --target native
else
  echo "== native tests SKIPPED: no C compiler (MSVC/gcc) on this host =="
  echo "   native 类型检查已在 'moon check --target all' 中通过；"
  echo "   native 纯库构建见 scripts/build-all.sh。"
fi

echo "ALL GREEN (on supported backends)"
